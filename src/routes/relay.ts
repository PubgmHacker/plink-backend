// src/routes/relay.ts — Protocol v2 HLS relay (ticket + manifest rewriter)
//
// Canonical P0 corrections applied on top of Rewrite 05:
//   - roomID is String (NOT uuid)
//   - returns RELATIVE playbackPath (`/api/media/stream/<token>`) — the
//     client resolves it against its API base URL. Returning absolute
//     PUBLIC_BASE_URL-prefixed URLs couples the backend to deployment DNS
//     and breaks behind reverse proxies.
//   - validates #EXTM3U body PREFIX (Content-Type alone is insufficient —
//     upstreams have been observed returning application/vnd.apple.mpegurl
//     for 200-OK error pages)
//   - rewrites RELATIVE URI lines + URI="..." attributes inside the
//     manifest body to ABSOLUTE allowlisted upstream URLs. Without this,
//     AVPlayer would resolve relative segment URIs against the relay
//     endpoint (which is not the segment host) and 404.
//   - uses `lookup` (NOT consume-and-delete) — AVPlayer refreshes the
//     playlist multiple times per session
import type { FastifyInstance } from 'fastify';

const HLS_MARKERS = ['/manifest/hls', 'hls_playlist', '.m3u8'];

function isTrustedHost(host: string): boolean {
  return (
    host === 'youtube.com' || host.endsWith('.youtube.com') ||
    host === 'googlevideo.com' || host.endsWith('.googlevideo.com')
  );
}

/**
 * Validate that a URL is an HTTPS HLS manifest on a trusted host.
 * Rejects: non-HTTPS, IP literals, credentials in URL, custom ports,
 * untrusted hosts, paths without HLS markers.
 */
function assertTrustedManifest(value: string): URL {
  const url = new URL(value);
  if (url.protocol !== 'https:' || url.username || url.password || url.port) {
    throw new Error('Only HTTPS manifest URLs are allowed');
  }
  const host = url.hostname.toLowerCase();
  if (!isTrustedHost(host)) throw new Error('Untrusted manifest host');
  if (/^\d{1,3}(\.\d{1,3}){3}$/.test(host) || host === 'localhost') {
    throw new Error('IP literals are not allowed');
  }
  const path = url.pathname.toLowerCase();
  if (!HLS_MARKERS.some((marker) => path.includes(marker))) {
    throw new Error('Only HLS manifests are allowed');
  }
  return url;
}

/**
 * Fetch a manifest, following up to 4 redirects. Each redirect Location
 * is re-validated against the trusted-host allowlist before following.
 */
async function fetchManifest(initial: URL): Promise<Response> {
  let current = initial;
  for (let attempt = 0; attempt < 4; attempt++) {
    const response = await fetch(current, {
      redirect: 'manual',
      headers: {
        'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15',
        Referer: 'https://www.youtube.com/',
      },
      signal: AbortSignal.timeout(10_000),
    });
    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = response.headers.get('location');
      if (!location) throw new Error('Invalid redirect');
      current = assertTrustedManifest(new URL(location, current).toString());
      continue;
    }
    return response;
  }
  throw new Error('Too many redirects');
}

/**
 * Rewrite relative URI lines + URI="..." attributes inside an HLS playlist
 * to ABSOLUTE allowlisted upstream URLs.
 *
 * - Plain segment lines (not starting with `#`): resolved against the
 *   manifest URL, host MUST be trusted.
 * - `#EXT-X-KEY:...,URI="..."` / `#EXT-X-MEDIA:...,URI="..."` attributes:
 *   the URI value is resolved against the manifest URL, host MUST be
 *   trusted.
 *
 * The signed query string on the manifest URL itself is NOT mutated —
 * we only resolve RELATIVE references against the manifest URL (which
 * preserves its existing query string on segment URIs that already carry
 * one, and inherits it on segment URIs that don't).
 *
 * Throws on any untrusted host encountered during rewriting.
 */
function rewritePlaylist(source: string, manifestURL: URL): string {
  return source
    .split(/\r?\n/)
    .map((line) => {
      const trimmed = line.trim();
      if (!trimmed) return line;

      // Segment URI line (no leading #)
      if (!trimmed.startsWith('#')) {
        const absolute = new URL(trimmed, manifestURL);
        if (!isTrustedHost(absolute.hostname.toLowerCase())) {
          throw new Error('Untrusted segment host');
        }
        return absolute.toString();
      }

      // #EXT-X-* tag — rewrite any URI="..." attributes inside
      return line.replace(/URI="([^"]+)"/g, (_match, value: string) => {
        const absolute = new URL(value, manifestURL);
        if (!isTrustedHost(absolute.hostname.toLowerCase())) {
          throw new Error('Untrusted URI attribute host');
        }
        return `URI="${absolute.toString()}"`;
      });
    })
    .join('\n');
}

export default async function relayRoutes(fastify: FastifyInstance): Promise<void> {
  // ── POST /api/media/relay-ticket ──────────────────────────────────────
  // Exchange (roomID, manifestURL) for a short-lived bearer token that the
  // client then uses to fetch the rewritten manifest at /api/media/stream/:token.
  fastify.post(
    '/media/relay-ticket',
    { preHandler: [(fastify as any).authenticate] },
    async (request: any, reply: any) => {
      const { roomID, manifestURL } = request.body ?? {};
      if (!roomID || !manifestURL) {
        return reply.status(400).send({ error: 'roomID and manifestURL required' });
      }

      let url: URL;
      try {
        url = assertTrustedManifest(manifestURL);
      } catch (e: any) {
        return reply.status(400).send({ error: e.message });
      }

      // Caller must be either a participant of the room OR the room's host.
      const membership = await fastify.prisma.roomParticipant
        .findUnique({
          where: { roomID_userID: { roomID, userID: request.user.id } },
        })
        .catch(() => null);
      const room = await fastify.prisma.room
        .findUnique({
          where: { id: roomID },
          select: { hostID: true },
        })
        .catch(() => null);
      if (!membership && room?.hostID !== request.user.id) {
        return reply.status(403).send({ error: 'Not a room member' });
      }

      const ticket = await fastify.relayTickets.issue({
        userID: request.user.id,
        roomID,
        manifestURL: url.toString(),
      });

      // Canonical P0: RELATIVE playbackPath — client resolves against its API base.
      return reply.send({
        playbackPath: `/api/media/stream/${ticket.token}`,
        expiresAtMS: ticket.expiresAtMS,
      });
    },
  );

  // ── GET /api/media/stream/:token ──────────────────────────────────────
  // AVPlayer fetches the manifest here. Token is reusable through TTL
  // (AVPlayer refreshes the playlist multiple times per session).
  fastify.get('/media/stream/:token', async (request: any, reply: any) => {
    reply.header('Cross-Origin-Resource-Policy', 'cross-origin');
    reply.header('Cache-Control', 'private, no-store');

    const ticket = await fastify.relayTickets.lookup(request.params.token);
    if (!ticket) {
      return reply.status(401).send({ error: 'Expired or invalid ticket' });
    }

    let upstream: Response;
    try {
      upstream = await fetchManifest(assertTrustedManifest(ticket.manifestURL));
    } catch (e: any) {
      return reply.status(400).send({ error: e.message });
    }
    if (!upstream.ok) {
      return reply.status(502).send({ error: `Manifest upstream ${upstream.status}` });
    }

    const text = await upstream.text();
    // Canonical P0: body-prefix check, NOT Content-Type alone. Upstreams have
    // been observed returning the mpegurl Content-Type on 200-OK error pages.
    if (Buffer.byteLength(text, 'utf8') > 2_000_000) {
      return reply.status(502).send({ error: 'Manifest too large' });
    }
    if (!text.trimStart().startsWith('#EXTM3U')) {
      return reply.status(502).send({ error: 'Invalid HLS manifest' });
    }

    let rewritten: string;
    try {
      rewritten = rewritePlaylist(text, new URL(ticket.manifestURL));
    } catch (e: any) {
      return reply.status(502).send({ error: e.message });
    }

    reply.type('application/vnd.apple.mpegurl');
    return reply.send(rewritten);
  });
}
