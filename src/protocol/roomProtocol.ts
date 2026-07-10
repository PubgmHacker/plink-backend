// src/protocol/roomProtocol.ts — Protocol v2 (Rewrite 01 + canonical P0 corrections)
//
// Canonical P0 corrections applied on top of Rewrite 01:
//   - roomID is String (NOT uuid) — domain IDs must not be UUID-typed
//   - roomEpoch added to envelope + command (per-room monotonic sequence boundary)
//   - measuredAtServerMS is stamped by the BACKEND (not the host client)
import { z } from 'zod';

export const ROOM_PROTOCOL_VERSION = 2 as const;

export const roomEventKindSchema = z.enum([
  'room.snapshot',
  'participant.joined',
  'participant.left',
  'media.changed',
  'playback.intent',
  'playback.snapshot',
  'chat.message',
  'reaction.sent',
  'queue.changed',
  'voice.signal',
  'system.error',
]);

export const mediaDescriptorSchema = z.object({
  mediaID: z.string().min(1).max(128),
  provider: z.enum(['youtube', 'direct', 'vk', 'rutube', 'other']),
  providerContentID: z.string().max(256).nullable(),
  title: z.string().min(1).max(300),
  thumbnailURL: z.string().url().nullable(),
  durationSeconds: z.number().finite().nonnegative().nullable(),
  playbackKind: z.enum(['hls', 'direct']),
  playbackReference: z.string().min(1).max(4096),
  expiresAtMS: z.number().int().positive().nullable(),
});

export const playbackIntentSchema = z.discriminatedUnion('action', [
  z.object({
    action: z.literal('play'),
    mediaTimeSeconds: z.number().finite().nonnegative(),
  }),
  z.object({
    action: z.literal('pause'),
    mediaTimeSeconds: z.number().finite().nonnegative(),
  }),
  z.object({
    action: z.literal('seek'),
    mediaTimeSeconds: z.number().finite().nonnegative(),
  }),
]);

export const playbackSnapshotSchema = z.object({
  mediaTimeSeconds: z.number().finite().nonnegative(),
  isPlaying: z.boolean(),
  // Canonical P0: stamped by the backend (Date.now()) at the moment it receives
  // the playback.intent. The host client NEVER sets this — it cannot be trusted.
  measuredAtServerMS: z.number().int().positive(),
});

export const clientRoomCommandSchema = z.object({
  protocolVersion: z.literal(ROOM_PROTOCOL_VERSION),
  clientEventID: z.string().uuid(),
  roomID: z.string().min(1).max(128),
  roomEpoch: z.string().min(1).max(128).optional(),
  expectedMediaRevision: z.number().int().nonnegative().nullable().optional(),
  kind: z.enum([
    'playback.intent',
    'chat.message',
    'reaction.sent',
    'voice.signal',
    'queue.vote',
    'state.request',
  ]),
  payload: z.unknown(),
});

export type ClientRoomCommand = z.infer<typeof clientRoomCommandSchema>;
export type MediaDescriptor = z.infer<typeof mediaDescriptorSchema>;
export type PlaybackIntent = z.infer<typeof playbackIntentSchema>;
export type PlaybackSnapshot = z.infer<typeof playbackSnapshotSchema>;
export type RoomEventKind = z.infer<typeof roomEventKindSchema>;

/**
 * Server → client envelope for all room events.
 *
 * Canonical P0: roomEpoch is REQUIRED (non-optional) on every published
 * envelope so clients can partition their per-epoch state (e.g. discard
 * late-arriving events from a stale epoch after re-joining).
 */
export interface RoomEnvelope<T = unknown> {
  protocolVersion: typeof ROOM_PROTOCOL_VERSION;
  eventID: string;
  roomID: string;
  roomEpoch: string;
  sequence: number;
  serverTimestampMS: number;
  senderUserID: string | null;
  mediaRevision: number;
  kind: RoomEventKind;
  payload: T;
}
