// src/protocol/roomCommandHandler.ts — Protocol v2 inbound command handler
//
// Canonical P0 corrections applied on top of Rewrite 01:
//   - roomID is String (NOT uuid)
//   - roomEpoch participates in routing + is forwarded on every publish
//   - measuredAtServerMS is stamped by the BACKEND here (Date.now()) for
//     playback.snapshot — the host client's clock is never trusted
//   - errors are emitted as Protocol v2 system.error envelopes, not ad-hoc
//     `{ type: 'error', message }` blobs
//
// Resolved imports from src/middleware/security.ts (verified to exist):
//   - isRoomHost(prisma, roomId, userId): Promise<boolean>
//   - sanitizeChatMessage(clientMsg, user, prisma?): Promise<chatPayload>
//   - checkRateLimit(userId): boolean  (10/s per user — global bucket)
import crypto from 'node:crypto';
import type { FastifyBaseLogger } from 'fastify';
import {
  clientRoomCommandSchema,
  playbackIntentSchema,
  playbackSnapshotSchema,
  ROOM_PROTOCOL_VERSION,
  type PlaybackIntent,
  type RoomEnvelope,
} from './roomProtocol.js';
import type { RoomEventService } from '../services/roomEventService.js';
import {
  isRoomHost,
  sanitizeChatMessage,
  checkRateLimit,
} from '../middleware/security.js';

// Protocol v2 socket shape (minimal — wired by the WS layer in a separate task).
// `any` is intentional: the existing ws-handler.ts uses a legacy socket shape
// and this handler will be adapted into the v2 WS upgrade path. Keeping the
// socket param as `any` avoids coupling to either shape during the rewrite.
export interface RoomCommandSocket {
  user?: { id: string; username: string; role: string };
  roomID?: string;
  roomEpoch?: string;
  send: (raw: string) => void;
  log?: FastifyBaseLogger;
}

export interface RoomCommandHandlerDeps {
  prisma: any;
  events: RoomEventService;
}

type SendError = (socket: RoomCommandSocket, code: string, message: string) => void;

function sendError(socket: RoomCommandSocket, code: string, message: string): void {
  const envelope: RoomEnvelope<{ code: string; message: string }> = {
    protocolVersion: ROOM_PROTOCOL_VERSION,
    eventID: crypto.randomUUID(),
    roomID: socket.roomID ?? '',
    roomEpoch: socket.roomEpoch ?? '',
    sequence: 0, // Out-of-band error: no sequence assignment
    serverTimestampMS: Date.now(),
    senderUserID: null,
    mediaRevision: 0,
    kind: 'system.error',
    payload: { code, message },
  };
  try {
    socket.send(JSON.stringify(envelope));
  } catch {
    // Socket may already be closed; nothing useful to do.
  }
}

// Wrapper kept for symmetry with the original spec; just delegates to
// crypto.randomUUID() so callers in this module read cleanly.
function cryptoRandomUUID(): string {
  return crypto.randomUUID();
}

export function createRoomCommandHandler(deps: RoomCommandHandlerDeps) {
  const { prisma, events } = deps;
  const errorSink: SendError = sendError;

  return async function handleRoomCommand(
    raw: string,
    socket: RoomCommandSocket,
  ): Promise<void> {
    // ── 1. Parse JSON ───────────────────────────────────────────────────
    let json: unknown;
    try {
      json = JSON.parse(raw);
    } catch {
      errorSink(socket, 'parse_error', 'Invalid JSON');
      return;
    }

    // ── 2. safeParse against Protocol v2 schema ────────────────────────
    const parsed = clientRoomCommandSchema.safeParse(json);
    if (!parsed.success) {
      errorSink(socket, 'schema_error', parsed.error.issues[0]?.message ?? 'Invalid command');
      return;
    }
    const command = parsed.data;

    // ── 3. Auth + room binding + epoch match ────────────────────────────
    if (!socket.user) {
      errorSink(socket, 'unauthenticated', 'Socket is not authenticated');
      return;
    }
    if (socket.roomID !== command.roomID) {
      errorSink(socket, 'room_mismatch', 'Command roomID does not match socket binding');
      return;
    }
    if (command.roomEpoch && socket.roomEpoch && command.roomEpoch !== socket.roomEpoch) {
      errorSink(socket, 'epoch_mismatch', 'Command roomEpoch is stale');
      return;
    }
    const roomEpoch = command.roomEpoch ?? socket.roomEpoch ?? '';
    if (!roomEpoch) {
      errorSink(socket, 'epoch_missing', 'No roomEpoch on command or socket');
      return;
    }

    // ── 4. Rate limit (global per-user bucket from security.ts) ─────────
    if (!checkRateLimit(socket.user.id)) {
      errorSink(socket, 'rate_limited', 'Too many commands');
      return;
    }

    // ── 5. Optional optimistic-concurrency guard on media revision ──────
    if (command.expectedMediaRevision != null) {
      const currentRevision = await events.mediaRevision(command.roomID);
      if (currentRevision !== command.expectedMediaRevision) {
        errorSink(socket, 'revision_conflict', `Expected ${command.expectedMediaRevision}, server is at ${currentRevision}`);
        return;
      }
    }

    const senderUserID = socket.user.id;

    // ── 6. Dispatch by kind ─────────────────────────────────────────────
    switch (command.kind) {
      // ── 6a. playback.intent (HOST-ONLY, backend re-stamps measuredAtServerMS)
      case 'playback.intent': {
        const intentParsed = playbackIntentSchema.safeParse(command.payload);
        if (!intentParsed.success) {
          errorSink(socket, 'schema_error', intentParsed.error.issues[0]?.message ?? 'Invalid intent');
          return;
        }
        const intent: PlaybackIntent = intentParsed.data;
        const host = await isRoomHost(prisma, command.roomID, senderUserID).catch(() => false);
        if (!host) {
          errorSink(socket, 'not_host', 'Only the room host may issue playback intents');
          return;
        }

        // Publish the inbound intent first (clients see the host's request).
        const mediaRevision = await events.mediaRevision(command.roomID);
        await events.publish<PlaybackIntent>({
          roomID: command.roomID,
          roomEpoch,
          senderUserID,
          mediaRevision,
          kind: 'playback.intent',
          payload: intent,
        });

        // Canonical P0: backend stamps measuredAtServerMS, NOT the host.
        const snapshot = {
          mediaTimeSeconds: intent.mediaTimeSeconds,
          isPlaying: intent.action === 'play',
          measuredAtServerMS: Date.now(),
        };
        // Sanity-check the snapshot shape we constructed.
        const snapshotParsed = playbackSnapshotSchema.safeParse(snapshot);
        if (!snapshotParsed.success) {
          errorSink(socket, 'internal_error', 'Constructed invalid snapshot');
          return;
        }
        await events.publish<typeof snapshot>({
          roomID: command.roomID,
          roomEpoch,
          senderUserID,
          mediaRevision,
          kind: 'playback.snapshot',
          payload: snapshotParsed.data,
        });
        return;
      }

      // ── 6b. chat.message (sanitized via security.ts)
      case 'chat.message': {
        const safe = await sanitizeChatMessage(
          { ...(command.payload as object), roomID: command.roomID },
          socket.user,
          prisma,
        ).catch(() => null);
        if (!safe) {
          errorSink(socket, 'internal_error', 'Chat message rejected');
          return;
        }
        try {
          await prisma.chatMessage.create({
            data: { roomID: safe.roomID, senderID: safe.senderID, text: safe.text },
          });
        } catch (e) {
          // Persistence failure is non-fatal — event still flows through pub/sub
          // so connected clients see the message; log and continue.
          const log = socket.log ?? console;
          (log as { warn?: (...args: unknown[]) => void }).warn?.(
            { err: (e as Error).message },
            'chat persist failed',
          );
        }
        const mediaRevision = await events.mediaRevision(command.roomID);
        await events.publish<typeof safe>({
          roomID: command.roomID,
          roomEpoch,
          senderUserID,
          mediaRevision,
          kind: 'chat.message',
          payload: safe,
        });
        return;
      }

      // ── 6c. reaction.sent / voice.signal / queue.vote — publish raw payload
      case 'reaction.sent':
      case 'voice.signal':
      case 'queue.vote': {
        const mediaRevision = await events.mediaRevision(command.roomID);
        await events.publish<unknown>({
          roomID: command.roomID,
          roomEpoch,
          senderUserID,
          mediaRevision,
          kind: command.kind === 'reaction.sent' ? 'reaction.sent'
            : command.kind === 'voice.signal' ? 'voice.signal'
            : 'queue.changed',
          payload: command.payload,
        });
        return;
      }

      // ── 6d. state.request — reply with the cached snapshot (no broadcast)
      case 'state.request': {
        const snapshot = await events.loadSnapshot<unknown>(command.roomID);
        const envelope: RoomEnvelope<unknown> = {
          protocolVersion: ROOM_PROTOCOL_VERSION,
          eventID: cryptoRandomUUID(),
          roomID: command.roomID,
          roomEpoch,
          sequence: 0,
          serverTimestampMS: Date.now(),
          senderUserID: null,
          mediaRevision: await events.mediaRevision(command.roomID),
          kind: 'room.snapshot',
          payload: snapshot ?? null,
        };
        socket.send(JSON.stringify(envelope));
        return;
      }

      default: {
        // Exhaustiveness guard — if the schema enum grows, this catches the gap.
        const _exhaustive: never = command.kind;
        errorSink(socket, 'unknown_kind', `Unhandled command kind: ${String(_exhaustive)}`);
        return;
      }
    }
  };
}
