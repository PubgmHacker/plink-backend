// src/services/relayTicketService.ts — Bearer token → manifest URL resolver
//
// Canonical P0 corrections applied on top of Rewrite 05:
//   - roomID is String (NOT uuid)
//   - ticket lookup is REUSABLE through TTL — do NOT delete on read.
//     The client may request the manifest multiple times during playback
//     (AVPlayer re-fetches the master playlist periodically, plus the
//     client may reload on resume). A consume-and-delete model would
//     break AVPlayer's auto-refresh.
//   - Token shape: 32 random bytes → base64url (43 chars, [A-Za-z0-9_-])
import crypto from 'node:crypto';
import type { Redis } from 'ioredis';

export interface RelayTicket {
  userID: string;
  roomID: string;
  manifestURL: string;
  expiresAtMS: number;
}

// 32 bytes → base64url → 43 chars, alphabet [A-Za-z0-9_-]
const TOKEN_RE = /^[A-Za-z0-9_-]{43}$/;

export class RelayTicketService {
  constructor(private redis: Redis) {}

  /**
   * Issue a new relay ticket. The token is opaque to the client; it is
   * exchanged at /api/media/stream/:token for the rewritten manifest.
   *
   * Default TTL = 90s. This is intentionally SHORT — long enough for the
   * AVPlayer to begin playback + refresh the playlist a few times, short
   * enough to limit the blast radius if the token leaks (e.g. via logs).
   * The client requests a fresh ticket whenever it needs to start a new
   * playback session.
   */
  async issue(
    input: Omit<RelayTicket, 'expiresAtMS'>,
    ttlSeconds = 90,
  ): Promise<{ token: string; expiresAtMS: number }> {
    const token = crypto.randomBytes(32).toString('base64url');
    const expiresAtMS = Date.now() + ttlSeconds * 1000;
    const ticket: RelayTicket = { ...input, expiresAtMS };
    await this.redis.set(`relay:${token}`, JSON.stringify(ticket), 'EX', ttlSeconds);
    return { token, expiresAtMS };
  }

  /**
   * Look up a ticket by token. Reusable until TTL expiry (Redis EX sets the
   * absolute TTL at write time; we don't need to delete on read).
   *
   * Canonical P0: callers MUST use `lookup` (not a consume-and-delete
   * pattern). The /api/media/stream/:token route is called many times per
   * playback session by AVPlayer's playlist refresher.
   *
   * Defensive: if the token shape is wrong, return null WITHOUT touching
   * Redis (avoids logging noise + the cost of a Redis round-trip for
   * obviously-malformed inputs).
   */
  async lookup(token: string): Promise<RelayTicket | null> {
    if (!TOKEN_RE.test(token)) return null;
    let raw: string | null;
    try {
      raw = await this.redis.get(`relay:${token}`);
    } catch {
      // Transient Redis error: fail closed (treat as expired).
      return null;
    }
    if (!raw) return null;
    let ticket: RelayTicket;
    try {
      ticket = JSON.parse(raw) as RelayTicket;
    } catch {
      return null;
    }
    // Defensive TTL check (Redis EX should have evicted already, but a clock
    // skew or repopulation race could leave a stale record).
    return ticket.expiresAtMS > Date.now() ? ticket : null;
  }
}
