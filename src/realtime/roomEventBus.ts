// src/realtime/roomEventBus.ts — Typed room event bus (Brain Review P0-3)
//
// Distributes ALL room-scoped events across replicas, not just sync.state.
// Used for: chat.broadcast, reaction.broadcast, participant.joined,
// participant.left.
//
// Each replica runs ONE subscriber per room it has local sockets in.
// When a router on replica A wants to broadcast a chat message:
//   1. It publishes to roomEvents:<roomId> via this bus.
//   2. ALL replicas (including A) receive the event via their subscriber.
//   3. Each replica fans out to its local sockets via registry.broadcastLocal.
//
// This ensures exactly-once delivery to each socket regardless of which
// replica published — NO split-brain, NO double-delivery (because the
// publisher does NOT also broadcastLocal directly; only the subscriber does).
//
// CRITICAL: the publishing router MUST NOT also call registry.broadcastLocal
// for the same event — that would double-deliver to local sockets on the
// publishing replica.

import Redis from 'ioredis';
import type { Redis as RedisType } from 'ioredis';

export type RoomEvent =
  | {
      kind: 'chat.broadcast';
      roomId: string;
      messageId: string;
      clientMessageId: string | null;
      senderId: string;
      senderName: string;
      text: string;
      createdAtMs: number;
    }
  | {
      kind: 'reaction.broadcast';
      roomId: string;
      userId: string;
      username: string;
      emoji: string;
      serverTimeMs: number;
    }
  | {
      kind: 'participant.joined';
      roomId: string;
      userId: string;
      username: string;
      timestampMs: number;
    }
  | {
      kind: 'participant.left';
      roomId: string;
      userId: string;
      username: string;
      timestampMs: number;
    };

export type RoomEventListener = (event: RoomEvent) => void;

export class RoomEventBus {
  private readonly subscriber: RedisType;
  private readonly publisher: RedisType;
  private readonly listeners = new Map<string, Set<RoomEventListener>>();
  private readonly subscribedChannels = new Set<string>();

  constructor(redisUrl: string) {
    // Dedicated subscriber connection (P0-2 rule: separate from publisher)
    this.subscriber = new Redis(redisUrl, {
      maxRetriesPerRequest: null,
      lazyConnect: false,
    });
    // Reuse a separate publisher connection (could be the main command client
    // in a future refactor, but kept separate here to keep this module
    // self-contained and avoid ordering issues during shutdown).
    this.publisher = new Redis(redisUrl, {
      maxRetriesPerRequest: 3,
      lazyConnect: false,
    });

    this.subscriber.on('message', (channel, raw) => {
      if (!channel.startsWith('roomEvents:')) return;
      const roomId = channel.substring('roomEvents:'.length);
      const set = this.listeners.get(roomId);
      if (!set || set.size === 0) return;
      let event: RoomEvent;
      try {
        event = JSON.parse(raw) as RoomEvent;
      } catch {
        return;
      }
      for (const fn of set) {
        try {
          fn(event);
        } catch (err) {
          console.error('[RoomEventBus] listener threw:', err);
        }
      }
    });

    this.subscriber.on('error', (err) => {
      console.warn('[RoomEventBus] subscriber error:', err.message);
    });
    this.publisher.on('error', (err) => {
      console.warn('[RoomEventBus] publisher error:', err.message);
    });
  }

  async publish(roomId: string, event: RoomEvent): Promise<void> {
    await this.publisher.publish(`roomEvents:${roomId}`, JSON.stringify(event));
  }

  async subscribe(roomId: string, listener: RoomEventListener): Promise<void> {
    let set = this.listeners.get(roomId);
    if (!set) {
      set = new Set();
      this.listeners.set(roomId, set);
    }
    set.add(listener);

    if (!this.subscribedChannels.has(roomId)) {
      await this.subscriber.subscribe(`roomEvents:${roomId}`);
      this.subscribedChannels.add(roomId);
    }
  }

  async unsubscribe(roomId: string, listener: RoomEventListener): Promise<void> {
    const set = this.listeners.get(roomId);
    if (!set) return;
    set.delete(listener);
    if (set.size === 0) {
      this.listeners.delete(roomId);
      if (this.subscribedChannels.has(roomId)) {
        await this.subscriber.unsubscribe(`roomEvents:${roomId}`);
        this.subscribedChannels.delete(roomId);
      }
    }
  }

  async close(): Promise<void> {
    await Promise.allSettled([this.subscriber.quit(), this.publisher.quit()]);
  }
}
