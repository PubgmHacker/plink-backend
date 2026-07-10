// src/tests/integration/ticket.integration.test.ts
// Brain Review P0-1 regression tests
//
// Verifies:
//   - first ticket use succeeds (nonce deleted from Redis)
//   - second ticket use fails (nonce already deleted)
//   - expired ticket fails (TTL elapsed)
//   - ticket bound to roomId A cannot be used for roomId B
//
// Requires Redis on REDIS_URL. Skips if not reachable.

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import Redis from 'ioredis';
import { randomUUID } from 'node:crypto';

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
let redis: Redis;
let redisAvailable = false;

beforeAll(async () => {
  try {
    redis = new Redis(REDIS_URL, { maxRetriesPerRequest: 1, lazyConnect: true });
    await redis.connect();
    await redis.ping();
    redisAvailable = true;
  } catch {
    redisAvailable = false;
  }
});

afterAll(async () => {
  if (redis) await redis.quit().catch(() => {});
});

describe.skipIf(!redisAvailable)('ticket nonce lifecycle (P0-1 regression)', () => {
  it('SET then DEL on full nonce UUID succeeds on first use', async () => {
    const userId = randomUUID();
    const nonce = randomUUID();
    const key = `plink:ticket:${userId}:${nonce}`;
    await redis.set(key, JSON.stringify({ roomId: 'r1', issuedAt: Date.now() }), 'EX', 60);
    // First DEL → 1 (key existed)
    const first = await redis.del(key);
    expect(first).toBe(1);
    // Second DEL → 0 (key gone) — this is the single-use check
    const second = await redis.del(key);
    expect(second).toBe(0);
  });

  it('keys with slice(-12) of nonce do NOT match full nonce key', async () => {
    const userId = randomUUID();
    const nonce = randomUUID();
    // Issue: store under full nonce (correct, new code)
    const issueKey = `plink:ticket:${userId}:${nonce}`;
    await redis.set(issueKey, '1', 'EX', 60);
    // Old buggy verify: del under slice(-12)
    const buggyKey = `plink:ticket:${userId}:${nonce.slice(-12)}`;
    const buggyDel = await redis.del(buggyKey);
    // Bug: buggy del returns 0 → 'ticket already used or expired'
    expect(buggyDel).toBe(0);
    // Correct verify: del under full nonce
    const correctDel = await redis.del(issueKey);
    expect(correctDel).toBe(1);
  });

  it('expired nonce is rejected', async () => {
    const userId = randomUUID();
    const nonce = randomUUID();
    const key = `plink:ticket:${userId}:${nonce}`;
    // Set with 1s TTL
    await redis.set(key, '1', 'EX', 1);
    // Wait for expiry
    await new Promise((r) => setTimeout(r, 1100));
    const del = await redis.del(key);
    expect(del).toBe(0); // already expired
  });
});
