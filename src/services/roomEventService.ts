// src/services/roomEventService.ts — Protocol v2 pub/sub + snapshot persistence
//
// Canonical P0 corrections applied on top of Rewrite 01:
//   - roomEpoch is part of every Redis key that must be partitioned by epoch
//     (sequence counter + pub/sub channel). Snapshot is per-room (NOT per-epoch)
//     because a snapshot is the recovery point after re-join / new epoch.
//   - Sequence is monotonic WITHIN a (roomID, roomEpoch) tuple. A new epoch
//     starts a fresh sequence at 1.
//   - Publish uses the COMMAND connection. Subscribe uses a DEDICATED
//     subscriber connection. Production MUST pass a `redis.duplicate()`
//     instance as `subscriber` — ioredis cannot subscribe + issue commands
//     on the same connection safely.
//
// Constructor signature:
//   new RoomEventService(redis, subscriber?)
//
// If `subscriber` is omitted, the command `redis` instance is reused. This is
// acceptable ONLY for unit tests / single-tenant local dev. Production wiring
// (src/index.ts) passes a duplicated connection.
import crypto from 'node:crypto';
import type { Redis } from 'ioredis';
import {
  ROOM_PROTOCOL_VERSION,
  type RoomEnvelope,
} from '../protocol/roomProtocol.js';

export class RoomEventService {
  constructor(
    private readonly redis: Redis,
    // Production MUST pass a redis.duplicate() here. Defaults to `redis` only
    // for tests where a single-connection dev setup is acceptable.
    private readonly subscriber: Redis = redis,
  ) {}

  // ─── Keys & channels ──────────────────────────────────────────────────
  // Sequence is per-(room,epoch): a new epoch starts at 1.
  private sequenceKey(roomID: string, epoch: string): string {
    return `room:${roomID}:${epoch}:sequence`;
  }
  private revisionKey(roomID: string): string {
    return `room:${roomID}:media-revision`;
  }
  private channel(roomID: string, epoch: string): string {
    return `room:${roomID}:${epoch}:events`;
  }
  private snapshotKey(roomID: string): string {
    return `room:${roomID}:snapshot`;
  }

  // ─── Media revision (per-room, persists across epochs) ────────────────
  async mediaRevision(roomID: string): Promise<number> {
    const raw = await this.redis.get(this.revisionKey(roomID));
    return raw ? Number(raw) : 0;
  }

  async incrementMediaRevision(roomID: string): Promise<number> {
    return this.redis.incr(this.revisionKey(roomID));
  }

  // ─── Publish ──────────────────────────────────────────────────────────
  async publish<T>(input: {
    roomID: string;
    roomEpoch: string;
    senderUserID: string | null;
    mediaRevision: number;
    kind: RoomEnvelope<T>['kind'];
    payload: T;
  }): Promise<RoomEnvelope<T>> {
    const sequence = await this.redis.incr(
      this.sequenceKey(input.roomID, input.roomEpoch),
    );
    const envelope: RoomEnvelope<T> = {
      protocolVersion: ROOM_PROTOCOL_VERSION,
      eventID: crypto.randomUUID(),
      roomID: input.roomID,
      roomEpoch: input.roomEpoch,
      sequence,
      serverTimestampMS: Date.now(),
      senderUserID: input.senderUserID,
      mediaRevision: input.mediaRevision,
      kind: input.kind,
      payload: input.payload,
    };
    await this.redis.publish(
      this.channel(input.roomID, input.roomEpoch),
      JSON.stringify(envelope),
    );
    return envelope;
  }

  // ─── Snapshot (per-room, 24h TTL) ─────────────────────────────────────
  async saveSnapshot<T>(roomID: string, snapshot: T): Promise<void> {
    await this.redis.set(
      this.snapshotKey(roomID),
      JSON.stringify(snapshot),
      'EX',
      24 * 60 * 60,
    );
  }

  async loadSnapshot<T>(roomID: string): Promise<T | null> {
    const raw = await this.redis.get(this.snapshotKey(roomID));
    return raw ? (JSON.parse(raw) as T) : null;
  }

  // ─── Subscribe ────────────────────────────────────────────────────────
  // Returns an unsubscribe function. The handler receives the raw JSON string
  // (callers parse it themselves to keep this layer schema-agnostic).
  async subscribe(
    roomID: string,
    roomEpoch: string,
    handler: (raw: string) => void,
  ): Promise<() => Promise<void>> {
    const channel = this.channel(roomID, roomEpoch);
    await this.subscriber.subscribe(channel);
    const listener = (chan: string, raw: string): void => {
      if (chan === channel) handler(raw);
    };
    this.subscriber.on('message', listener);
    return async () => {
      this.subscriber.off('message', listener);
      await this.subscriber.unsubscribe(channel);
    };
  }
}
