// src/realtime/messageRouter.ts — Type-based WS message router (runbook §5)
//
// FIXES the §19 bug: 'stateRequest должен обрабатываться до generic command
// routing'. The old ws-handler.ts checked `msg.command && msg.roomID` BEFORE
// `msg.command === 'stateRequest' && msg.roomID` — so stateRequest was
// shadowed and never reached.
//
// v2 design (runbook §5):
//   1. Single JSON parse, single schema validation, single switch on `type`.
//   2. membership check BEFORE any room-scoped action.
//   3. host check with 1-2s cache + invalidation.
//   4. bufferedAmount > 512KB → close slow consumer.
//   5. heartbeat isAlive via WS ping frames every 20s.
//   6. per-type rate limits: sync 20/sec burst 30, chat 5/10s, reactions 2/s.
//   7. graceful shutdown: stop accepting, notify draining, close after 10s.

import type { WebSocket } from 'ws';
import type { PrismaClient } from '@prisma/client';
import {
  ClientMessageSchema,
  StateRequestSchema,
  SyncCommandSchema,
  ChatSendSchema,
  ReactionSendSchema,
  ClockProbeSchema,
  type RoomState,
  type SyncStateMessage,
  type SyncStateSnapshotMessage,
  type ChatBroadcast,
  type ParticipantEvent,
  type ErrorMessage,
  type SessionReady,
} from '../contracts/realtime-v2.js';
import type { RoomStateStore } from './roomStateStore.js';
import type { RoomPubSub } from './roomPubSub.js';
import type { ConnectionRegistry, PlinkSocket } from './connectionRegistry.js';

// ─────────────────────────────────────────────────────────────────────────────
// Rate limits (per-type, per-socket)
// ─────────────────────────────────────────────────────────────────────────────
const RATE_LIMITS = {
  'sync.command': { max: 20, windowMs: 1000, burst: 30 },
  'sync.state.request': { max: 5, windowMs: 1000, burst: 10 },
  'chat.send': { max: 5, windowMs: 10_000, burst: 8 },
  'reaction.send': { max: 2, windowMs: 1000, burst: 4 },
  'clock.probe': { max: 10, windowMs: 1000, burst: 20 },
} as const;

type RateBucket = { count: number; resetAt: number };

// ─────────────────────────────────────────────────────────────────────────────
// Host check cache: roomId → { hostId, expiresAt }
// Invalidated on host migration / participant role change.
// ─────────────────────────────────────────────────────────────────────────────
const HOST_CACHE_TTL_MS = 2000;
const hostCache = new Map<string, { hostId: string; expiresAt: number }>();

async function isHost(prisma: PrismaClient, roomId: string, userId: string): Promise<boolean> {
  const cached = hostCache.get(roomId);
  const now = Date.now();
  if (cached && cached.expiresAt > now) {
    return cached.hostId === userId;
  }
  const room = await prisma.room.findUnique({
    where: { id: roomId },
    select: { hostID: true },
  });
  if (!room) return false;
  hostCache.set(roomId, { hostId: room.hostID, expiresAt: now + HOST_CACHE_TTL_MS });
  return room.hostID === userId;
}

/** Invalidate host cache — called on host migration, room teardown, etc. */
export function invalidateHostCache(roomId: string): void {
  hostCache.delete(roomId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Membership check: confirms user is in RoomParticipant for this room.
// DB-checked — never trust the socket's claim alone.
// ─────────────────────────────────────────────────────────────────────────────
async function isRoomMember(prisma: PrismaClient, roomId: string, userId: string): Promise<boolean> {
  try {
    const participant = await prisma.roomParticipant.findUnique({
      where: { roomID_userID: { roomID: roomId, userID: userId } },
      select: { leftAt: true },
    });
    return participant !== null && participant.leftAt === null;
  } catch {
    // schema may not have composite key — fall back to first matching participant row
    const participant = await prisma.roomParticipant.findFirst({
      where: { roomID: roomId, userID: userId, leftAt: null },
      select: { id: true },
    });
    return participant !== null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error helper — type-safe ErrorMessage
// ─────────────────────────────────────────────────────────────────────────────
function sendError(socket: PlinkSocket, code: string, message: string): void {
  const payload: ErrorMessage = {
    type: 'error',
    protocolVersion: 2,
    code,
    message,
  };
  if (socket.readyState === socket.OPEN) socket.send(JSON.stringify(payload));
}

// ─────────────────────────────────────────────────────────────────────────────
// Rate limit check
// ─────────────────────────────────────────────────────────────────────────────
function checkRateLimit(socket: PlinkSocket, type: keyof typeof RATE_LIMITS): boolean {
  const limit = RATE_LIMITS[type];
  const now = Date.now();
  if (!socket._rateBuckets) socket._rateBuckets = new Map();
  let bucket: RateBucket | undefined = socket._rateBuckets.get(type);
  if (!bucket || now > bucket.resetAt) {
    bucket = { count: 0, resetAt: now + limit.windowMs };
    socket._rateBuckets.set(type, bucket);
  }
  bucket.count++;
  return bucket.count <= limit.max + limit.burst;
}

// ─────────────────────────────────────────────────────────────────────────────
// Slow consumer guard (runbook §5)
// ─────────────────────────────────────────────────────────────────────────────
function checkSlowConsumer(socket: PlinkSocket): boolean {
  // @ts-expect-error bufferedAmount exists on ws.WebSocket
  const buffered = (socket.bufferedAmount ?? 0) as number;
  if (buffered > 512 * 1024) {
    sendError(socket, 'SLOW_CONSUMER', 'Buffered amount exceeded 512KB — closing');
    socket.close(1011, 'Slow consumer');
    return false;
  }
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main router
// ─────────────────────────────────────────────────────────────────────────────
export interface RouterDeps {
  prisma: PrismaClient;
  store: RoomStateStore;
  pubsub: RoomPubSub;
  registry: ConnectionRegistry;
  /**
   * Returns the current epoch for a room. Typically reads from the last
   * known state in Redis (via store.get), defaulting to 1.
   */
  currentEpoch: (roomId: string) => Promise<number>;
}

export function createMessageRouter(deps: RouterDeps) {
  const { prisma, store, pubsub, registry, currentEpoch } = deps;

  /**
   * Handle a single inbound WebSocket message.
   * All control flow is type-based — no `msg.command && msg.roomID` shadowing.
   */
  async function handleMessage(socket: PlinkSocket, raw: Buffer): Promise<void> {
    // §5: payload size guard
    if (raw.byteLength > 64 * 1024) {
      socket.close(1009, 'Payload too large');
      return;
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(raw.toString('utf8'));
    } catch {
      sendError(socket, 'INVALID_JSON', 'Message is not valid JSON');
      return;
    }

    // Single schema parse — discriminatedUnion('type', ...) rejects unknown
    // types AND validates per-type shape with .strict().
    let msg;
    try {
      msg = ClientMessageSchema.parse(parsed);
    } catch (err) {
      sendError(socket, 'SCHEMA_INVALID', (err as Error).message.substring(0, 400));
      return;
    }

    // Slow consumer check before any work
    if (!checkSlowConsumer(socket)) return;

    switch (msg.type) {
      // ── sync.state.request ─────────────────────────────────────────────
      // CRITICAL: handled FIRST in v2 (the §19 bug fix). The old code's
      // `msg.command && msg.roomID` shadowed this case.
      case 'sync.state.request': {
        if (!checkRateLimit(socket, 'sync.state.request')) {
          sendError(socket, 'RATE_LIMITED', 'state.request rate limit exceeded');
          return;
        }
        const m = StateRequestSchema.parse(parsed);
        // Membership check (§5)
        if (!(await isRoomMember(prisma, m.roomId, socket.userId!))) {
          sendError(socket, 'NOT_MEMBER', 'User is not a member of this room');
          return;
        }
        const state = await store.get(m.roomId);
        const reply: SyncStateSnapshotMessage = {
          type: 'sync.state.snapshot',
          protocolVersion: 2,
          roomId: m.roomId,
          state,
          serverTimeMs: Date.now(),
        };
        socket.send(JSON.stringify(reply));
        return;
      }

      // ── sync.command (host-only) ───────────────────────────────────────
      case 'sync.command': {
        if (!checkRateLimit(socket, 'sync.command')) {
          sendError(socket, 'RATE_LIMITED', 'sync.command rate limit exceeded');
          return;
        }
        const m = SyncCommandSchema.parse(parsed);
        if (!(await isRoomMember(prisma, m.roomId, socket.userId!))) {
          sendError(socket, 'NOT_MEMBER', 'User is not a member of this room');
          return;
        }
        if (!(await isHost(prisma, m.roomId, socket.userId!))) {
          sendError(socket, 'NOT_HOST', 'Only the host can control playback');
          return;
        }
        const epoch = await currentEpoch(m.roomId);
        const result = await store.apply({
          roomId: m.roomId,
          actionId: m.actionId,
          epoch,
          mediaId: m.mediaId,
          positionMs: m.positionMs,
          playing: m.playing,
          rate: m.rate,
          issuedBy: socket.userId!,
        });
        if (result.kind === 'stale_epoch') {
          sendError(socket, 'STALE_EPOCH', 'Server epoch is ahead — refetch snapshot');
          return;
        }
        // result.kind === 'applied' | 'replay'
        // Lua PUBLISH already fired for 'applied'; this replica's local
        // subscribers (RoomPubSub) will fan it out to local connections.
        // For 'replay', we don't republish (idempotent no-op).
        if (result.kind === 'replay' && result.state) {
          // Send the current state back to the caller so they can reconcile
          const reply: SyncStateMessage = {
            type: 'sync.state',
            protocolVersion: 2,
            roomId: m.roomId,
            state: result.state,
            serverTimeMs: Date.now(),
          };
          socket.send(JSON.stringify(reply));
        }
        return;
      }

      // ── chat.send ──────────────────────────────────────────────────────
      case 'chat.send': {
        if (!checkRateLimit(socket, 'chat.send')) {
          sendError(socket, 'RATE_LIMITED', 'chat rate limit exceeded');
          return;
        }
        const m = ChatSendSchema.parse(parsed);
        if (!(await isRoomMember(prisma, m.roomId, socket.userId!))) {
          sendError(socket, 'NOT_MEMBER', 'User is not a member of this room');
          return;
        }
        // Persist
        const created = await prisma.chatMessage.create({
          data: {
            roomID: m.roomId,
            senderID: socket.userId!,
            text: m.text,
          },
        });
        // Broadcast — identity comes from JWT, not payload (§5)
        const broadcast: ChatBroadcast = {
          type: 'chat.broadcast',
          protocolVersion: 2,
          roomId: m.roomId,
          messageId: created.id,
          clientMessageId: m.clientMessageId,
          senderId: socket.userId!,
          senderName: socket.username ?? 'unknown',
          text: m.text,
          createdAtMs: created.createdAt?.getTime?.() ?? Date.now(),
        };
        registry.broadcastLocal(m.roomId, broadcast, /* exclude */ socket);
        return;
      }

      // ── reaction.send ──────────────────────────────────────────────────
      case 'reaction.send': {
        if (!checkRateLimit(socket, 'reaction.send')) {
          sendError(socket, 'RATE_LIMITED', 'reaction rate limit exceeded');
          return;
        }
        const m = ReactionSendSchema.parse(parsed);
        if (!(await isRoomMember(prisma, m.roomId, socket.userId!))) {
          sendError(socket, 'NOT_MEMBER', 'User is not a member of this room');
          return;
        }
        registry.broadcastLocal(
          m.roomId,
          {
            type: 'reaction.broadcast',
            protocolVersion: 2,
            roomId: m.roomId,
            userId: socket.userId!,
            username: socket.username ?? 'unknown',
            emoji: m.emoji,
            serverTimeMs: Date.now(),
          },
          /* exclude */ socket,
        );
        return;
      }

      // ── clock.probe ────────────────────────────────────────────────────
      case 'clock.probe': {
        if (!checkRateLimit(socket, 'clock.probe')) {
          return; // silent — clock probes should not produce error spam
        }
        const m = ClockProbeSchema.parse(parsed);
        socket.send(
          JSON.stringify({
            type: 'clock.probe.reply',
            protocolVersion: 2,
            clientSentMs: m.clientSentMs,
            serverMs: Date.now(),
          }),
        );
        return;
      }

      default: {
        // Exhaustiveness check — TypeScript guarantees we handled every case.
        // Reaching here means a new message type was added to the schema but
        // not to this switch.
        const _exhaustive: never = msg;
        void _exhaustive;
        sendError(socket, 'UNKNOWN_MESSAGE_TYPE', `Unhandled type: ${(msg as { type: string }).type}`);
        return;
      }
    }
  }

  return { handleMessage };
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers for the gateway to broadcast state to local connections
// (called when RoomPubSub listener fires)
// ─────────────────────────────────────────────────────────────────────────────
export function makeSyncStateMessage(roomId: string, state: RoomState): SyncStateMessage {
  return {
    type: 'sync.state',
    protocolVersion: 2,
    roomId,
    state,
    serverTimeMs: Date.now(),
  };
}

export function makeParticipantEvent(
  kind: 'participant.joined' | 'participant.left',
  roomId: string,
  userId: string,
  username: string,
): ParticipantEvent {
  return {
    type: kind,
    protocolVersion: 2,
    roomId,
    userId,
    username,
    joinedAtMs: kind === 'participant.joined' ? Date.now() : undefined,
    leftAtMs: kind === 'participant.left' ? Date.now() : undefined,
  };
}

export function makeSessionReady(roomId: string, role: 'host' | 'viewer'): SessionReady {
  return {
    type: 'session.ready',
    protocolVersion: 2,
    roomId,
    role,
    serverTimeMs: Date.now(),
  };
}
