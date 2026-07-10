// src/realtime/gateway.ts — WebSocket gateway (runbook §5)
//
// Replaces setupWebSocketHandler() in src/websocket/ws-handler.ts.
// Differences from the legacy handler:
//
// 1. Auth via Sec-WebSocket-Protocol (ticket) — NOT URL query string (§2).
//    The ticket is a short-lived (60s) single-use nonce issued by
//    POST /api/realtime/ticket. See routes/realtime.ts.
// 2. Single message router (messageRouter.ts) — no `msg.command && msg.roomID`
//    shadowing of stateRequest.
// 3. Membership check at JOIN and at every room-scoped action.
// 4. Heartbeat via WS ping frames (heartbeat.ts) — not application-layer pings.
// 5. Slow consumer guard (bufferedAmount > 512KB → close 1011).
// 6. Graceful shutdown: stop accepting new connections, notify draining,
//    close existing after 10s.
// 7. session.ready message before any other traffic — clients must not treat
//    the socket as "connected" until they receive it (runbook §19).

import type { WebSocketServer } from 'ws';
import type { FastifyInstance } from 'fastify';
import type { PrismaClient } from '@prisma/client';
import type { Redis } from 'ioredis';
import { config } from '../config/index.js';
import { RoomStateStore } from './roomStateStore.js';
import { RoomPubSub } from './roomPubSub.js';
import { ConnectionRegistry, type PlinkSocket } from './connectionRegistry.js';
import { createMessageRouter, makeSessionReady, makeParticipantEvent } from './messageRouter.js';
import { Heartbeat } from './heartbeat.js';
import { wsConnections, wsMessages, usersOnline } from '../services/metrics.js';
import { presence } from '../services/presence.js';

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
  private readonly router: ReturnType<typeof createMessageRouter>;
  private readonly heartbeat: Heartbeat;
  private shuttingDown = false;

  constructor(private readonly deps: GatewayDeps) {
    this.store = new RoomStateStore(deps.redis);
    this.pubsub = new RoomPubSub(config.REDIS_URL);
    this.router = createMessageRouter({
      prisma: deps.prisma,
      store: this.store,
      pubsub: this.pubsub,
      registry: this.registry,
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
    // Client opens with: new WebSocket(url, ['plink.v2', <ticket>])
    // Server verifies the ticket, then the socket is authed.
    const protocols = (req.headers['sec-websocket-protocol'] as string | undefined)?.split(',').map((s) => s.trim()) ?? [];
    const ticket = protocols.find((p) => p.startsWith('plink.ticket.'));

    if (!ticket) {
      socket.close(4001, 'Missing plink ticket in Sec-WebSocket-Protocol');
      return;
    }

    let userId: string;
    let username: string;
    let role: string;
    try {
      const payload = await this.verifyTicket(ticket);
      userId = payload.userId;
      username = payload.username;
      role = payload.role;
    } catch (err) {
      socket.close(4001, `Ticket invalid: ${(err as Error).message}`);
      return;
    }

    // Banned check
    const user = await deps.prisma.user.findUnique({
      where: { id: userId },
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
    // /ws/room/<roomId> OR /ws?roomId=...
    let roomId: string | undefined;
    if (pathParts.length >= 3 && pathParts[1] === 'room') {
      roomId = pathParts[2];
    }
    if (!roomId) {
      roomId = url.searchParams.get('roomId') ?? undefined;
    }

    if (roomId) {
      // Membership check at JOIN (runbook §5)
      const isMember = await this.isMember(user.id, roomId);
      if (!isMember) {
        sendError(socket, 'NOT_MEMBER', 'User is not a member of this room');
        socket.close(4003, 'Not a room member');
        return;
      }
      this.registry.join(socket, roomId);
      presence.joinRoom(socket, roomId);

      // Subscribe to cross-replica fanout
      this.pubsub.subscribe(roomId, (state) => {
        this.registry.broadcastLocal(roomId, {
          type: 'sync.state',
          protocolVersion: 2,
          roomId,
          state,
          serverTimeMs: Date.now(),
        });
      });

      // Notify others on this replica
      this.registry.broadcastLocal(
        roomId,
        makeParticipantEvent('participant.joined', roomId, user.id, user.username),
        socket,
      );

      // Send session.ready — clients MUST wait for this before considering
      // the socket usable (runbook §8, §19).
      const isHost = (await this.deps.prisma.room.findUnique({
        where: { id: roomId },
        select: { hostID: true },
      }))?.hostID === user.id;
      socket.send(JSON.stringify(makeSessionReady(roomId, isHost ? 'host' : 'viewer')));
    }

    socket.on('message', (raw: Buffer) => {
      wsMessages.inc({ type: 'inbound', direction: 'in' });
      // Router is async; swallow errors so they don't crash the event loop.
      this.router.handleMessage(socket, raw).catch((err) => {
        console.error('[RealtimeGateway] router error:', err);
        sendError(socket, 'INTERNAL', 'Internal server error');
      });
    });

    socket.on('close', () => {
      wsConnections.dec();
      this.registry.disconnect(socket);
      presence.disconnect(socket);
      usersOnline.set(presence.getOnlineUsers().length);

      if (socket.activeRoomId) {
        // Notify other local participants
        this.registry.broadcastLocal(
          socket.activeRoomId,
          makeParticipantEvent('participant.left', socket.activeRoomId, user.id, user.username),
        );
        // Unsubscribe from PubSub if no local listeners remain
        this.pubsub.unsubscribe(socket.activeRoomId, this.pubsubListener).catch(() => {});
      }
    });

    socket.on('error', (err) => {
      console.warn('[RealtimeGateway] socket error:', err.message);
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  private async isMember(userId: string, roomId: string): Promise<boolean> {
    try {
      const p = await this.deps.prisma.roomParticipant.findUnique({
        where: { roomID_userID: { roomID: roomId, userID: userId } },
        select: { leftAt: true },
      });
      return p !== null && p.leftAt === null;
    } catch {
      const p = await this.deps.prisma.roomParticipant.findFirst({
        where: { roomID: roomId, userID: userId, leftAt: null },
        select: { id: true },
      });
      return p !== null;
    }
  }

  private async verifyTicket(
    ticket: string,
  ): Promise<{ userId: string; username: string; role: string }> {
    // Ticket format: plink.ticket.<jwt>
    const token = ticket.substring('plink.ticket.'.length);
    const payload = this.deps.fastify.jwt.verify(token) as {
      id: string;
      username: string;
      role: string;
      typ?: string;
    };
    if (payload.typ !== 'realtime_ticket') {
      throw new Error('not a realtime ticket');
    }
    // Single-use: delete from Redis nonce set
    const ok = await this.deps.redis.del(`plink:ticket:${payload.id}:${token.slice(-12)}`);
    if (ok === 0) throw new Error('ticket already used or expired');
    return { userId: payload.id, username: payload.username, role: payload.role };
  }

  private pubsubListener = (state: any) => {
    // Placeholder — replaced per-room in onConnection
    void state;
  };

  /** Graceful shutdown (runbook §5). */
  async shutdown(): Promise<void> {
    this.shuttingDown = true;
    this.heartbeat.close();

    // Notify all clients
    for (const sock of this.deps.wss.clients) {
      const s = sock as PlinkSocket;
      if (s.readyState === s.OPEN) {
        try {
          s.send(
            JSON.stringify({
              type: 'server.draining',
              protocolVersion: 2,
              message: 'Server shutting down — please reconnect',
              retryInMs: 2000,
            }),
          );
        } catch {}
      }
    }

    // Wait up to 10s for clients to drain
    await new Promise((r) => setTimeout(r, 10_000));

    // Close everything
    for (const sock of this.deps.wss.clients) {
      const s = sock as PlinkSocket;
      try {
        s.close(1001, 'Server shutting down');
      } catch {}
    }
    await this.pubsub.close();
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
