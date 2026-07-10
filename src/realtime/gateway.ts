// src/realtime/gateway.ts — WebSocket gateway (runbook §5 + Brain Review 2 fixes)
//
// Brain Review 2 fixes:
//
// P0-15: cleanup handlers registered IMMEDIATELY after onConnection entry,
//   before any await. Idempotent cleanup tracks what was committed
//   (presence, metrics, registry, listeners) and only rolls back what
//   actually happened. Rejection paths (no room, ticket mismatch, banned,
//   not member, PubSub failure) no longer leak presence/metrics/registry.
//
// P0-16: session.ready role derived from CURRENT DB query, not stale ticket
//   claim. isMemberOrHost() now returns { allowed, isHost } from a single
//   DB check, and that current isHost is used for session.ready.
//
// P1-12: participant events use Redis-backed presence count. We publish
//   participant.joined only when the user's first connection for this room
//   joins (count 0 → 1), and participant.left only when the last connection
//   leaves (count 1 → 0). Multi-device users no longer spam join/leave.

import type { WebSocketServer } from 'ws';
import type { FastifyInstance } from 'fastify';
import type { PrismaClient } from '@prisma/client';
import type { Redis } from 'ioredis';
import { config } from '../config/index.js';
import { RoomStateStore } from './roomStateStore.js';
import { RoomPubSub, type RoomStateListener } from './roomPubSub.js';
import { RoomEventBus, type RoomEvent, type RoomEventListener } from './roomEventBus.js';
import { ConnectionRegistry, type PlinkSocket } from './connectionRegistry.js';
import { createMessageRouter, makeSessionReady, makeParticipantEvent } from './messageRouter.js';
import { Heartbeat } from './heartbeat.js';
import { wsConnections, wsMessages, usersOnline } from '../services/metrics.js';
import { presence } from '../services/presence.js';
import type { ServerMessage } from '../contracts/realtime-v2.js';

export interface GatewayDeps {
  fastify: FastifyInstance;
  prisma: PrismaClient;
  redis: Redis;
  wss: WebSocketServer;
}

export class RealtimeGateway {
  private readonly registry = new ConnectionRegistry();
  private readonly store: RoomStateStore;
  private readonly pubsub: RoomPubSub;
  private readonly eventBus: RoomEventBus;
  private readonly router: ReturnType<typeof createMessageRouter>;
  private readonly heartbeat: Heartbeat;

  private readonly roomListeners = new Map<string, RoomStateListener>();
  private readonly roomEventListeners = new Map<string, RoomEventListener>();
  private shuttingDown = false;

  constructor(private readonly deps: GatewayDeps) {
    this.store = new RoomStateStore(deps.redis);
    this.pubsub = new RoomPubSub(config.REDIS_URL);
    this.eventBus = new RoomEventBus(config.REDIS_URL);

    this.router = createMessageRouter({
      prisma: deps.prisma,
      store: this.store,
      pubsub: this.pubsub,
      registry: this.registry,
      eventBus: this.eventBus,
      currentEpoch: async (roomId) => {
        const s = await this.store.get(roomId);
        return s?.epoch ?? 1;
      },
    });
    this.heartbeat = new Heartbeat(deps.wss, this.registry);

    deps.wss.on('connection', (socket: PlinkSocket, req) => this.onConnection(socket, req));
  }

  private async onConnection(socket: PlinkSocket, req: any): Promise<void> {
    if (this.shuttingDown) {
      socket.close(1001, 'Server shutting down');
      return;
    }

    // ── P0-15: register cleanup handlers IMMEDIATELY, before any await ──
    // Idempotent — tracks what was committed and only rolls back that.
    let cleaned = false;
    let connectedPresence = false;
    let incrementedMetrics = false;
    let joinedRoomId: string | undefined;
    let retainedRoom = false;

    const cleanup = async () => {
      if (cleaned) return;
      cleaned = true;
      if (joinedRoomId) {
        this.registry.disconnect(socket);
        await this.releaseRoomIfEmpty(joinedRoomId).catch(() => {});
      }
      if (retainedRoom) {
        // retainedRoom is released via releaseRoomIfEmpty above
      }
      if (connectedPresence) {
        presence.disconnect(socket);
        if (incrementedMetrics) {
          wsConnections.dec();
          usersOnline.set(presence.getOnlineUsers().length);
        }
      }
    };
    socket.once('close', () => void cleanup());
    socket.once('error', () => void cleanup());

    // ── Auth via Sec-WebSocket-Protocol (runbook §2) ────────────────────
    const protocols = (req.headers['sec-websocket-protocol'] as string | undefined)
      ?.split(',')
      .map((s) => s.trim()) ?? [];
    const ticket = protocols.find((p) => p.startsWith('plink.ticket.'));

    if (!ticket) {
      socket.close(4001, 'Missing plink ticket in Sec-WebSocket-Protocol');
      await cleanup();
      return;
    }

    let ticketPayload: {
      userId: string;
      username: string;
      role: string;
      roomId: string;
      isHost: boolean;
    };
    try {
      ticketPayload = await this.verifyTicket(ticket);
    } catch (err) {
      socket.close(4001, `Ticket invalid: ${(err as Error).message}`);
      await cleanup();
      return;
    }

    // Banned check
    const user = await this.deps.prisma.user.findUnique({
      where: { id: ticketPayload.userId },
      select: { id: true, username: true, role: true, bannedUntil: true },
    });
    if (!user) {
      socket.close(4001, 'User not found');
      await cleanup();
      return;
    }
    if (user.bannedUntil && user.bannedUntil > new Date()) {
      socket.close(4003, 'User banned');
      await cleanup();
      return;
    }

    socket.userId = user.id;
    socket.username = user.username;
    socket.role = user.role;
    socket.isAlive = true;

    // ── Parse roomId from URL path (NOT query) ──────────────────────────
    const url = new URL(req.url, 'http://localhost');
    const pathParts = url.pathname.split('/').filter(Boolean);
    let wsRoomId: string | undefined;
    if (pathParts.length >= 3 && pathParts[1] === 'room') {
      wsRoomId = pathParts[2];
    }
    if (!wsRoomId) {
      wsRoomId = url.searchParams.get('roomId') ?? undefined;
    }

    if (!wsRoomId) {
      sendError(socket, 'NO_ROOM', 'roomId required in WS path');
      socket.close(4001, 'roomId required');
      await cleanup();
      return;
    }

    // P0-1: ticket is bound to roomId — WS path must match ticket.roomId.
    if (wsRoomId !== ticketPayload.roomId) {
      sendError(socket, 'ROOM_MISMATCH', 'Ticket roomId does not match WS path roomId');
      socket.close(4003, 'Ticket room mismatch');
      await cleanup();
      return;
    }
    const roomId = wsRoomId;

    // P0-16: derive current role from DB, not stale ticket claim.
    // isMemberOrHost returns { allowed, isHost } from single DB check.
    const membership = await this.isMemberOrHost(user.id, roomId);
    if (!membership.allowed) {
      sendError(socket, 'NOT_MEMBER', 'User is not a member or host of this room');
      socket.close(4003, 'Not a room member or host');
      await cleanup();
      return;
    }
    const currentIsHost = membership.isHost;

    // ── Commit presence + metrics (after all rejection paths) ───────────
    presence.connect(socket, user.id, user.username);
    wsConnections.inc();
    usersOnline.set(presence.getOnlineUsers().length);
    connectedPresence = true;
    incrementedMetrics = true;

    this.registry.join(socket, roomId);
    presence.joinRoom(socket, roomId);
    joinedRoomId = roomId;

    // P0-2: retain ONE pubsub listener for this room on this replica.
    try {
      await this.retainRoom(roomId);
      retainedRoom = true;
    } catch (err) {
      sendError(socket, 'PUBSUB_FAILED', `Failed to subscribe: ${(err as Error).message}`);
      socket.close(1011, 'PubSub subscribe failed');
      await cleanup();
      return;
    }

    // P1-12: Redis-backed presence count. Publish participant.joined only
    // when this is the user's FIRST connection for this room (count 0 → 1).
    const joinedCount = await this.bumpRoomPresence(roomId, user.id);
    if (joinedCount === 1) {
      await this.eventBus.publish(roomId, {
        kind: 'participant.joined',
        roomId,
        userId: user.id,
        username: user.username,
        timestampMs: Date.now(),
      });
    }

    // P0-16: session.ready role from CURRENT DB state, not ticket claim.
    socket.send(JSON.stringify(makeSessionReady(roomId, currentIsHost ? 'host' : 'viewer')));

    socket.on('message', (raw: Buffer) => {
      wsMessages.inc({ type: 'inbound', direction: 'in' });
      this.router.handleMessage(socket, raw).catch((err) => {
        console.error('[RealtimeGateway] router error:', err);
        sendError(socket, 'INTERNAL', 'Internal server error');
      });
    });

    // Replace the early 'close' once handler with the real one now that
    // we have committed state. The early handler called cleanup() which
    // is idempotent — safe to call again.
    socket.removeAllListeners('close');
    socket.on('close', () => {
      void cleanup();
      // P1-12: decrement presence count; publish left only when last conn leaves
      this.decrementRoomPresence(roomId, user.id).then((count) => {
        if (count === 0) {
          this.eventBus
            .publish(roomId, {
              kind: 'participant.left',
              roomId,
              userId: user.id,
              username: user.username,
              timestampMs: Date.now(),
            })
            .catch(() => {});
        }
      }).catch(() => {});
    });
  }

  // ── P1-12: Redis-backed presence count ────────────────────────────────
  private async bumpRoomPresence(roomId: string, userId: string): Promise<number> {
    const key = `plink:presence:${roomId}:${userId}`;
    const count = await this.deps.redis.incr(key);
    // 30 minute TTL — auto-cleanup if socket dies without close event
    await this.deps.redis.expire(key, 1800);
    return count;
  }

  private async decrementRoomPresence(roomId: string, userId: string): Promise<number> {
    const key = `plink:presence:${roomId}:${userId}`;
    const count = await this.deps.redis.decr(key);
    if (count <= 0) {
      await this.deps.redis.del(key);
      return 0;
    }
    return count;
  }

  // ── P0-2: ref-counted room listeners ───────────────────────────────────
  private async retainRoom(roomId: string): Promise<void> {
    if (!this.roomListeners.has(roomId)) {
      const listener: RoomStateListener = (state) => {
        const msg: ServerMessage = {
          type: 'sync.state',
          protocolVersion: 2,
          roomId,
          state,
          serverTimeMs: Date.now(),
        };
        this.registry.broadcastLocal(roomId, msg);
      };
      this.roomListeners.set(roomId, listener);
      await this.pubsub.subscribe(roomId, listener);
    }

    if (!this.roomEventListeners.has(roomId)) {
      const eventListener: RoomEventListener = (event) => {
        const msg = this.eventToServerMessage(event);
        if (msg) this.registry.broadcastLocal(roomId, msg);
      };
      this.roomEventListeners.set(roomId, eventListener);
      await this.eventBus.subscribe(roomId, eventListener);
    }
  }

  private async releaseRoomIfEmpty(roomId: string): Promise<void> {
    if (this.registry.getRoomSockets(roomId).length > 0) return;

    const stateListener = this.roomListeners.get(roomId);
    if (stateListener) {
      this.roomListeners.delete(roomId);
      await this.pubsub.unsubscribe(roomId, stateListener);
    }
    const eventListener = this.roomEventListeners.get(roomId);
    if (eventListener) {
      this.roomEventListeners.delete(roomId);
      await this.eventBus.unsubscribe(roomId, eventListener);
    }
  }

  private eventToServerMessage(event: RoomEvent): ServerMessage | null {
    switch (event.kind) {
      case 'participant.joined':
        return makeParticipantEvent('participant.joined', event.roomId, event.userId, event.username);
      case 'participant.left':
        return makeParticipantEvent('participant.left', event.roomId, event.userId, event.username);
      case 'chat.broadcast':
        return {
          type: 'chat.broadcast',
          protocolVersion: 2,
          roomId: event.roomId,
          messageId: event.messageId,
          clientMessageId: event.clientMessageId ?? null,
          senderId: event.senderId,
          senderName: event.senderName,
          text: event.text,
          createdAtMs: event.createdAtMs,
        };
      case 'reaction.broadcast':
        return {
          type: 'reaction.broadcast',
          protocolVersion: 2,
          roomId: event.roomId,
          userId: event.userId,
          username: event.username,
          emoji: event.emoji,
          serverTimeMs: event.serverTimeMs,
        };
      default:
        return null;
    }
  }

  // ── P0-16: isMemberOrHost returns { allowed, isHost } from single DB check ─
  private async isMemberOrHost(userId: string, roomId: string): Promise<{ allowed: boolean; isHost: boolean }> {
    const [participant, room] = await Promise.all([
      this.deps.prisma.roomParticipant
        .findUnique({
          where: { roomID_userID: { roomID: roomId, userID: userId } },
          select: { id: true },
        })
        .catch(() => null),
      this.deps.prisma.room.findUnique({
        where: { id: roomId },
        select: { hostID: true, isActive: true },
      }),
    ]);
    if (!room || !room.isActive) return { allowed: false, isHost: false };
    const isHost = room.hostID === userId;
    const isMember = participant !== null;
    return { allowed: isHost || isMember, isHost };
  }

  private async verifyTicket(ticket: string): Promise<{
    userId: string;
    username: string;
    role: string;
    roomId: string;
    isHost: boolean;
  }> {
    const token = ticket.substring('plink.ticket.'.length);
    const payload = this.deps.fastify.jwt.verify(token) as {
      id: string;
      username: string;
      role: string;
      roomId: string;
      nonce: string;
      host?: boolean;
      typ?: string;
    };
    if (payload.typ !== 'realtime_ticket') {
      throw new Error('not a realtime ticket');
    }
    if (!payload.roomId || !payload.nonce) {
      throw new Error('ticket missing roomId or nonce');
    }
    const ok = await this.deps.redis.del(`plink:ticket:${payload.id}:${payload.nonce}`);
    if (ok === 0) throw new Error('ticket already used or expired');
    return {
      userId: payload.id,
      username: payload.username,
      role: payload.role,
      roomId: payload.roomId,
      isHost: payload.host === true,
    };
  }

  /** Graceful shutdown (runbook §5, P1-6). */
  async shutdown(): Promise<void> {
    this.shuttingDown = true;
    this.heartbeat.close();

    const drainMessage = JSON.stringify({
      type: 'server.draining',
      protocolVersion: 2,
      message: 'Server shutting down — please reconnect',
      retryInMs: 2000,
    });
    for (const sock of this.deps.wss.clients) {
      const s = sock as PlinkSocket;
      if (s.readyState === s.OPEN) {
        try {
          s.send(drainMessage);
        } catch {}
      }
    }

    const drainDeadline = Date.now() + 10_000;
    while (Date.now() < drainDeadline) {
      if (this.deps.wss.clients.size === 0) break;
      await new Promise((r) => setTimeout(r, 250));
    }

    for (const sock of this.deps.wss.clients) {
      const s = sock as PlinkSocket;
      try {
        s.close(1001, 'Server shutting down');
      } catch {}
    }
    await Promise.allSettled([this.pubsub.close(), this.eventBus.close()]);
  }
}

function sendError(socket: PlinkSocket, code: string, message: string): void {
  if (socket.readyState !== socket.OPEN) return;
  socket.send(
    JSON.stringify({
      type: 'error',
      protocolVersion: 2,
      code,
      message,
    }),
  );
}
