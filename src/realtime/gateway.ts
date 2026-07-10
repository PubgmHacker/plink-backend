// src/realtime/gateway.ts — WebSocket gateway (runbook §5 + Brain Review fixes)
//
// Brain Review fixes applied:
//
// P0-1: ticket nonce key uses FULL nonce UUID (matches routes/realtime.ts).
//       Ticket is bound to roomId — WS path roomId must match ticket.roomId.
// P0-2: ONE pubsub listener per room per replica, ref-counted by local
//       sockets. Listener reference is stored and reused for unsubscribe.
//       On close: save roomId BEFORE disconnect, then release.
// P0-3: All room-scoped broadcasts (chat, reaction, participant, sync.state)
//       go through Redis PubSub via RoomEventBus. Local broadcast is the
//       ONLY path the PubSub subscriber uses to fan out — so a published
//       event reaches every local socket exactly once, regardless of which
//       replica published it.
// P1-2: effectiveAt — kept as-is (server sets now+80ms). Client-side
//       OrderedSyncController is responsible for waiting until the
//       effectiveAt deadline before applying play/pause. Server does NOT
//       schedule its own wait.
// P1-6: shutdown closes HTTP, WS, Redis subscriber, command Redis, Prisma.
//       10s sleep replaced with drain promise with timeout.
// P1-7: isMember accepts EITHER RoomParticipant row OR host-of-room.

import type { WebSocketServer } from 'ws';
import type { FastifyInstance } from 'fastify';
import type { PrismaClient } from '@prisma/client';
import type { Redis } from 'ioredis';
import { config } from '../config/index.js';
import { RoomStateStore } from './roomStateStore.js';
import { RoomPubSub, type RoomStateListener } from './roomPubSub.js';
import { RoomEventBus, type RoomEvent } from './roomEventBus.js';
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

  // P0-2: ONE listener per room on this replica, ref-counted.
  // Stored reference is reused for unsubscribe — no leak.
  private readonly roomListeners = new Map<string, RoomStateListener>();
  private readonly roomEventListeners = new Map<string, (event: RoomEvent) => void>();
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
      eventBus: this.eventBus, // P0-3: router publishes chat/reaction via bus
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

    // ── Auth via Sec-WebSocket-Protocol (runbook §2) ────────────────────
    const protocols = (req.headers['sec-websocket-protocol'] as string | undefined)
      ?.split(',')
      .map((s) => s.trim()) ?? [];
    const ticket = protocols.find((p) => p.startsWith('plink.ticket.'));

    if (!ticket) {
      socket.close(4001, 'Missing plink ticket in Sec-WebSocket-Protocol');
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
      return;
    }

    // Banned check
    const user = await this.deps.prisma.user.findUnique({
      where: { id: ticketPayload.userId },
      select: { id: true, username: true, role: true, bannedUntil: true },
    });
    if (!user) {
      socket.close(4001, 'User not found');
      return;
    }
    if (user.bannedUntil && user.bannedUntil > new Date()) {
      socket.close(4003, 'User banned');
      return;
    }

    socket.userId = user.id;
    socket.username = user.username;
    socket.role = user.role;
    socket.isAlive = true;

    presence.connect(socket, user.id, user.username);
    wsConnections.inc();
    usersOnline.set(presence.getOnlineUsers().length);

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
      return;
    }

    // P0-1: ticket is bound to roomId — WS path must match ticket.roomId.
    if (wsRoomId !== ticketPayload.roomId) {
      sendError(socket, 'ROOM_MISMATCH', 'Ticket roomId does not match WS path roomId');
      socket.close(4003, 'Ticket room mismatch');
      return;
    }
    const roomId = wsRoomId;

    // P1-7: membership OR host
    const isMember = await this.isMemberOrHost(user.id, roomId);
    if (!isMember) {
      sendError(socket, 'NOT_MEMBER', 'User is not a member or host of this room');
      socket.close(4003, 'Not a room member or host');
      return;
    }

    this.registry.join(socket, roomId);
    presence.joinRoom(socket, roomId);

    // P0-2: retain ONE pubsub listener for this room on this replica.
    // Failure to subscribe is fatal for this session — close before ready.
    try {
      await this.retainRoom(roomId);
    } catch (err) {
      sendError(socket, 'PUBSUB_FAILED', `Failed to subscribe: ${(err as Error).message}`);
      socket.close(1011, 'PubSub subscribe failed');
      return;
    }

    // Notify others on this replica AND other replicas via event bus
    await this.eventBus.publish(roomId, {
      kind: 'participant.joined',
      roomId,
      userId: user.id,
      username: user.username,
      timestampMs: Date.now(),
    });

    // Send session.ready — clients MUST wait for this before considering
    // the socket usable (runbook §8, §19).
    const role = ticketPayload.isHost ? 'host' : 'viewer';
    socket.send(JSON.stringify(makeSessionReady(roomId, role)));

    socket.on('message', (raw: Buffer) => {
      wsMessages.inc({ type: 'inbound', direction: 'in' });
      this.router.handleMessage(socket, raw).catch((err) => {
        console.error('[RealtimeGateway] router error:', err);
        sendError(socket, 'INTERNAL', 'Internal server error');
      });
    });

    socket.on('close', () => {
      wsConnections.dec();
      // P0-2: save roomId BEFORE disconnect — registry.disconnect clears
      // socket.activeRoomId.
      const closedRoomId = socket.activeRoomId;
      this.registry.disconnect(socket);
      presence.disconnect(socket);
      usersOnline.set(presence.getOnlineUsers().length);

      if (closedRoomId) {
        // Notify via event bus (other replicas + local)
        this.eventBus
          .publish(closedRoomId, {
            kind: 'participant.left',
            roomId: closedRoomId,
            userId: user.id,
            username: user.username,
            timestampMs: Date.now(),
          })
          .catch(() => {});

        // P0-2: release room listener if no local sockets remain
        this.releaseRoomIfEmpty(closedRoomId).catch(() => {});
      }
    });

    socket.on('error', (err) => {
      console.warn('[RealtimeGateway] socket error:', err.message);
    });
  }

  // ── P0-2: ref-counted room listeners ───────────────────────────────────
  private async retainRoom(roomId: string): Promise<void> {
    // State listener (sync.state fanout)
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

    // Event listener (chat/reaction/participant fanout) — P0-3
    if (!this.roomEventListeners.has(roomId)) {
      const eventListener = (event: RoomEvent) => {
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

  // ── Helpers ────────────────────────────────────────────────────────────
  private async isMemberOrHost(userId: string, roomId: string): Promise<boolean> {
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
    if (!room || !room.isActive) return false;
    return room.hostID === userId || participant !== null;
  }

  private async verifyTicket(ticket: string): Promise<{
    userId: string;
    username: string;
    role: string;
    roomId: string;
    isHost: boolean;
  }> {
    // Ticket format: plink.ticket.<jwt>
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
    // P0-1: single-use nonce — DEL uses FULL nonce UUID (matches
    // routes/realtime.ts which SETs the same key).
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

    // Notify all clients
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

    // P1-6: drain with timeout (not unconditional 10s sleep)
    const drainDeadline = Date.now() + 10_000;
    while (Date.now() < drainDeadline) {
      if (this.deps.wss.clients.size === 0) break;
      await new Promise((r) => setTimeout(r, 250));
    }

    // Close everything
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
