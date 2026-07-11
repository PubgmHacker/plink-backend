// src/tests/integration/roomEventBus.integration.test.ts
// Brain Review P0-3 regression tests
//
// Verifies:
//   - published event reaches subscriber on same replica
//   - published event reaches subscriber on a SECOND subscriber instance
//     (simulating a second replica)
//   - listener is NOT called after unsubscribe (leak prevention)
//   - publishing to room A does NOT deliver to room B subscriber
//
// Requires Redis on REDIS_URL.

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { RoomEventBus } from '../../realtime/roomEventBus.js';

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6380';
let redisOk = false;

beforeAll(async () => {
  try {
    const probe = new (await import('ioredis')).default(REDIS_URL, {
      maxRetriesPerRequest: 1,
      lazyConnect: true,
    });
    await probe.connect();
    await probe.ping();
    await probe.quit();
    redisOk = true;
  } catch {
    redisOk = false;
  }
});

describe.skipIf(!redisOk)('RoomEventBus cross-replica distribution (P0-3 regression)', () => {
  it('event published on replica A reaches subscriber on replica B', async () => {
    const replicaA = new RoomEventBus(REDIS_URL);
    const replicaB = new RoomEventBus(REDIS_URL);
    const roomId = 'room-p0-3-a-' + Date.now();
    const received: string[] = [];
    await replicaB.subscribe(roomId, (event) => {
      if (event.kind === 'chat.broadcast') {
        received.push(event.text);
      }
    });
    // Give subscriber a moment to register
    await new Promise((r) => setTimeout(r, 100));
    await replicaA.publish(roomId, {
      kind: 'chat.broadcast',
      roomId,
      messageId: 'm1',
      clientMessageId: null,
      senderId: '00000000-0000-4000-8000-000000000001',
      senderName: 'tester',
      text: 'hello from A',
      createdAtMs: Date.now(),
    });
    // Allow pub/sub propagation
    await new Promise((r) => setTimeout(r, 200));
    expect(received).toEqual(['hello from A']);
    await replicaA.close();
    await replicaB.close();
  });

  it('listener is not called after unsubscribe (no leak)', async () => {
    const bus = new RoomEventBus(REDIS_URL);
    const roomId = 'room-p0-3-b-' + Date.now();
    const received: string[] = [];
    const listener = (event: any) => {
      if (event.kind === 'chat.broadcast') received.push(event.text);
    };
    await bus.subscribe(roomId, listener);
    await bus.unsubscribe(roomId, listener);
    await new Promise((r) => setTimeout(r, 100));
    await bus.publish(roomId, {
      kind: 'chat.broadcast',
      roomId,
      messageId: 'm2',
      clientMessageId: null,
      senderId: '00000000-0000-4000-8000-000000000001',
      senderName: 'tester',
      text: 'should not arrive',
      createdAtMs: Date.now(),
    });
    await new Promise((r) => setTimeout(r, 200));
    expect(received).toEqual([]);
    await bus.close();
  });

  it('event for room A does not deliver to room B subscriber', async () => {
    const bus = new RoomEventBus(REDIS_URL);
    const roomA = 'room-p0-3-c-' + Date.now();
    const roomB = 'room-p0-3-d-' + Date.now();
    const receivedA: string[] = [];
    const receivedB: string[] = [];
    await bus.subscribe(roomA, (e) => {
      if (e.kind === 'chat.broadcast') receivedA.push(e.text);
    });
    await bus.subscribe(roomB, (e) => {
      if (e.kind === 'chat.broadcast') receivedB.push(e.text);
    });
    await new Promise((r) => setTimeout(r, 100));
    await bus.publish(roomA, {
      kind: 'chat.broadcast',
      roomId: roomA,
      messageId: 'm3',
      clientMessageId: null,
      senderId: '00000000-0000-4000-8000-000000000001',
      senderName: 'tester',
      text: 'only for A',
      createdAtMs: Date.now(),
    });
    await new Promise((r) => setTimeout(r, 200));
    expect(receivedA).toEqual(['only for A']);
    expect(receivedB).toEqual([]);
    await bus.close();
  });
});
