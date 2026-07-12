// src/routes/media.ts — Pack 3: обновлённый с yt-dlp extraction
import { extractStream, extractYouTubeStream, extractMetadata, UPSTREAM_USER_AGENT } from '../services/streamExtractor.js';
import { youtubePlayerHTML } from '../services/youtubePlayer.js';
import { proxyYouTubeEmbed } from '../services/youtubeEmbedProxy.js';
import { cacheGet, cacheSet, cacheDel } from '../config/redis.js';
import { config } from '../config/index.js';

const EXTRACT_CACHE_TTL = 3600; // 1 час — прямой URL живёт долго

export default async function mediaRoutes(fastify, _options) {
  const YOUTUBE_API_KEY = process.env.YOUTUBE_API_KEY;
  // Brain Phase 1.2: App Store compliant builds must NOT register extraction/proxy routes.
  // When APP_STORE_COMPLIANT=true, /api/media/extract, /extract-url, /youtube-stream, /youtube-embed
  // all return 404. Only /search, /trending, /categories, /metadata (read-only YouTube Data API)
  // and /youtube-player (official IFrame wrapper) are exposed.
  const COMPLIANT = config.APP_STORE_COMPLIANT;

  // ═══════════════════════════════════════════════════════════════════
  // GET /api/media/search?q=запрос&limit=12 — YouTube поиск
  // 🔧 v28 (July 2026): removed `preHandler: [fastify.authenticate]` —
  // search is now PUBLIC. Rationale:
  //   1. YouTubeSearchView creates its own YouTubeSearchService instance
  //      without DI of the auth token, so authenticated search would 401.
  //   2. Search is a read-only proxy to YouTube Data API v3 — no user-
  //      specific data is exposed.
  //   3. Rate limiting (30 req/min) still protects against quota abuse.
  //   4. YOUTUBE_API_KEY is server-side only — never exposed to clients.
  //
  // Brain Phase 3: after search.list, batch IDs through videos.list with
  // part=snippet,contentDetails,status to populate embeddable, privacyStatus,
  // liveBroadcastContent, durationSeconds. iOS uses embeddable to disable
  // rows where the video cannot be embedded in Plink.
  // ═══════════════════════════════════════════════════════════════════
  fastify.get('/media/search', {
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } }
  }, async (request: any, reply: any) => {
    const { q, limit = '12' } = request.query as any;

    if (!q) return reply.status(400).send({ error: 'Query required' });
    if (!YOUTUBE_API_KEY) {
      return reply.status(500).send({ error: 'YOUTUBE_API_KEY not configured' });
    }

    // Cache key
    const cacheKey = `yt:search:${q}:${limit}`;
    const cached = await cacheGet<any[]>(cacheKey);
    if (cached) return reply.send({ results: cached });

    const searchUrl = new URL('https://www.googleapis.com/youtube/v3/search');
    searchUrl.searchParams.set('part', 'snippet');
    searchUrl.searchParams.set('q', q);
    searchUrl.searchParams.set('type', 'video');
    searchUrl.searchParams.set('maxResults', String(limit));
    searchUrl.searchParams.set('key', YOUTUBE_API_KEY);

    try {
      const resp = await fetch(searchUrl.toString());
      if (!resp.ok) {
        const errText = await resp.text();
        console.error('YouTube API error', resp.status, errText);
        return reply.status(resp.status).send({ error: 'YouTube API error' });
      }
      const data: any = await resp.json();

      const videoIds: string[] = (data.items || [])
        .filter((item: any) => item.id?.videoId)
        .map((item: any) => item.id.videoId);

      if (videoIds.length === 0) {
        await cacheSet(cacheKey, [], 600);
        return reply.send({ results: [] });
      }

      // Brain Phase 3: batch videos.list to fetch embeddable + duration + status
      const detailsUrl = new URL('https://www.googleapis.com/youtube/v3/videos');
      detailsUrl.searchParams.set('part', 'snippet,contentDetails,status');
      detailsUrl.searchParams.set('id', videoIds.join(','));
      detailsUrl.searchParams.set('key', YOUTUBE_API_KEY);

      const detailsResp = await fetch(detailsUrl.toString());
      const detailsData: any = detailsResp.ok ? await detailsResp.json() : { items: [] };

      // Index details by video ID for O(1) lookup
      const detailsById: Record<string, any> = {};
      for (const item of detailsData.items || []) {
        detailsById[item.id] = item;
      }

      // Build results preserving search order, enriched with status fields
      const results = videoIds.map((videoId) => {
        const searchItem = (data.items || []).find((i: any) => i.id?.videoId === videoId);
        const detail = detailsById[videoId];

        // Parse ISO 8601 duration
        let durationSeconds: number | null = null;
        const dur = detail?.contentDetails?.duration;
        if (dur) {
          const match = dur.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
          if (match) {
            const hours = parseInt(match[1] || '0');
            const mins = parseInt(match[2] || '0');
            const secs = parseInt(match[3] || '0');
            durationSeconds = hours * 3600 + mins * 60 + secs;
          }
        }

        return {
          id: videoId,
          videoId,
          title: searchItem?.snippet?.title || detail?.snippet?.title || '',
          channel: searchItem?.snippet?.channelTitle || detail?.snippet?.channelTitle || '',
          channelTitle: searchItem?.snippet?.channelTitle || detail?.snippet?.channelTitle || '',
          thumbnailURL: searchItem?.snippet?.thumbnails?.medium?.url ||
                        detail?.snippet?.thumbnails?.medium?.url ||
                        searchItem?.snippet?.thumbnails?.default?.url ||
                        detail?.snippet?.thumbnails?.default?.url || null,
          durationSeconds,
          liveBroadcastContent: detail?.snippet?.liveBroadcastContent || 'none',
          embeddable: detail?.status?.embeddable ?? true,
          privacyStatus: detail?.status?.privacyStatus || null,
          url: `https://www.youtube.com/watch?v=${videoId}`,
        };
      });

      await cacheSet(cacheKey, results, 600); // 10 min
      reply.send({ results });
    } catch (e: any) {
      console.error('Search error', e);
      reply.status(500).send({ error: 'Search failed' });
    }
  });

  // ═══════════════════════════════════════════════════════════════════
  // GET /api/media/trending — YouTube trending / popular videos
  // 🔧 v33 (July 2026): returns popular videos for YouTube search screen
  // "Recommendations" section. Uses YouTube Data API v3 videos.list with
  // chart=mostPopular. No auth required (read-only, cached 1 hour).
  // ═══════════════════════════════════════════════════════════════════
  fastify.get('/media/trending', {
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } }
  }, async (request: any, reply: any) => {
    const { regionCode = 'RU', maxResults = '20' } = request.query as any;

    if (!YOUTUBE_API_KEY) {
      return reply.status(500).send({ error: 'YOUTUBE_API_KEY not configured' });
    }

    const cacheKey = `yt:trending:${regionCode}:${maxResults}`;
    const cached = await cacheGet<any[]>(cacheKey);
    if (cached) return reply.send({ results: cached });

    // Use videos.list with chart=mostPopular to get trending videos.
    // Brain Phase 3: include `status` part to populate embeddable + privacyStatus.
    const url = new URL('https://www.googleapis.com/youtube/v3/videos');
    url.searchParams.set('part', 'snippet,contentDetails,status');
    url.searchParams.set('chart', 'mostPopular');
    url.searchParams.set('regionCode', regionCode);
    url.searchParams.set('maxResults', String(maxResults));
    url.searchParams.set('videoCategoryId', '0');  // all categories
    url.searchParams.set('key', YOUTUBE_API_KEY);

    try {
      const resp = await fetch(url.toString());
      if (!resp.ok) {
        const errText = await resp.text();
        console.error('YouTube trending API error', resp.status, errText);
        return reply.status(resp.status).send({ error: 'YouTube API error' });
      }
      const data: any = await resp.json();

      const results = (data.items || [])
        .filter((item: any) => item.id)
        .map((item: any) => {
          const videoId = item.id;
          // Parse ISO 8601 duration (PT1H30M15S → 5415 seconds)
          let durationSeconds: number | null = null;
          if (item.contentDetails?.duration) {
            const match = item.contentDetails.duration.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
            if (match) {
              const hours = parseInt(match[1] || '0');
              const mins = parseInt(match[2] || '0');
              const secs = parseInt(match[3] || '0');
              durationSeconds = hours * 3600 + mins * 60 + secs;
            }
          }
          return {
            id: videoId,
            videoId,
            title: item.snippet?.title || '',
            channel: item.snippet?.channelTitle || '',
            channelTitle: item.snippet?.channelTitle || '',
            thumbnailURL: item.snippet?.thumbnails?.medium?.url ||
                          item.snippet?.thumbnails?.high?.url ||
                          item.snippet?.thumbnails?.default?.url || null,
            durationSeconds,
            liveBroadcastContent: item.snippet?.liveBroadcastContent || 'none',
            embeddable: item.status?.embeddable ?? true,
            privacyStatus: item.status?.privacyStatus || null,
            url: `https://www.youtube.com/watch?v=${videoId}`,
          };
        });

      await cacheSet(cacheKey, results, 3600); // 1 hour cache
      reply.send({ results });
    } catch (e: any) {
      console.error('Trending error', e);
      reply.status(500).send({ error: 'Trending fetch failed' });
    }
  });

  // ═══════════════════════════════════════════════════════════════════
  // GET /api/media/categories — YouTube video categories for search screen
  // 🔧 v33: returns category chips (Music, Gaming, News, etc.)
  // ═══════════════════════════════════════════════════════════════════
  fastify.get('/media/categories', {
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } }
  }, async (request: any, reply: any) => {
    // Static categories — YouTube's guideCategories API requires auth + is slow
    // We hardcode popular categories that users actually care about
    const categories = [
      { id: '0', title: 'Все', query: '' },
      { id: '10', title: 'Музыка', query: 'music' },
      { id: '20', title: 'Игры', query: 'gaming' },
      { id: '25', title: 'Новости', query: 'news' },
      { id: '23', title: 'Комедии', query: 'comedy' },
      { id: '24', title: 'Развлечения', query: 'entertainment' },
      { id: '22', title: 'Люди и блоги', query: 'people' },
      { id: '26', title: 'Стиль', query: 'fashion' },
      { id: '27', title: 'Образование', query: 'education' },
      { id: '28', title: 'Наука', query: 'science' },
      { id: '17', title: 'Спорт', query: 'sport' },
      { id: '19', title: 'Путешествия', query: 'travel' },
      { id: '2', title: 'Авто', query: 'cars' },
      { id: '1', title: 'Фильмы', query: 'movies' },
    ];
    reply.send({ results: categories });
  });

  // ═══════════════════════════════════════════════════════════════════
  // GET /api/media/extract?id=VIDEO_ID — YouTube stream extraction (yt-dlp)
  // Brain Phase 1.2: registered ONLY in non-compliant builds.
  // ═══════════════════════════════════════════════════════════════════
  if (!COMPLIANT) {
  fastify.get('/media/extract', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 20, timeWindow: '1 minute' } }
  }, async (request: any, reply: any) => {
    const { id } = request.query as any;
    if (!id) return reply.status(400).send({ error: 'Video ID required' });

    // Cache extraction (URL YouTube живёт ~6 часов)
    const cacheKey = `yt:stream:${id}`;
    const cached = await cacheGet<any>(cacheKey);
    if (cached) {
      return reply.send(cached);
    }

    try {
      const stream = await extractYouTubeStream(id);
      await cacheSet(cacheKey, stream, EXTRACT_CACHE_TTL);
      reply.send(stream);
    } catch (e: any) {
      console.error('YouTube extract error', e.message);
      
      // Fallback: oEmbed (только метаданные, без streamURL)
      try {
        const oembedUrl = `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${id}&format=json`;
        const resp = await fetch(oembedUrl);
        if (resp.ok) {
          const data: any = await resp.json();
          return reply.send({
            id,
            title: data.title,
            author: data.author_name,
            thumbnailURL: data.thumbnail_url,
            embedURL: `https://www.youtube.com/embed/${id}?autoplay=1&playsinline=1&rel=0`,
            watchURL: `https://www.youtube.com/watch?v=${id}`,
            streamURL: null,  // не удалось извлечь прямой поток
            fallback: 'embed',
          });
        }
      } catch {}
      
      reply.status(500).send({ error: 'Extract failed: ' + e.message });
    }
  });
  } // end if (!COMPLIANT) — /media/extract

  // ═══════════════════════════════════════════════════════════════════
  // POST /api/media/extract-url — извлечение по любому URL (VK, RuTube, etc.)
  // Brain Phase 1.2: registered ONLY in non-compliant builds.
  // ═══════════════════════════════════════════════════════════════════
  if (!COMPLIANT) {
  fastify.post('/media/extract-url', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 20, timeWindow: '1 minute' } }
  }, async (request: any, reply: any) => {
    const { url } = request.body;
    if (!url) return reply.status(400).send({ error: 'URL required' });

    const cacheKey = `stream:${Buffer.from(url).toString('base64').slice(0, 40)}`;
    const cached = await cacheGet<any>(cacheKey);
    if (cached) return reply.send(cached);

    try {
      const stream = await extractStream(url);
      await cacheSet(cacheKey, stream, EXTRACT_CACHE_TTL);
      reply.send(stream);
    } catch (e: any) {
      console.error('Extract URL error', e.message);
      reply.status(500).send({ error: 'Extract failed: ' + e.message });
    }
  });
  } // end if (!COMPLIANT) — /media/extract-url

  // ═══════════════════════════════════════════════════════════════════
  // GET /api/media/metadata?url=... — только метаданные (без stream)
  // ═══════════════════════════════════════════════════════════════════
  fastify.get('/media/metadata', {
    preHandler: [fastify.authenticate],
    config: { rateLimit: { max: 60, timeWindow: '1 minute' } }
  }, async (request: any, reply: any) => {
    const { url } = request.query as any;
    if (!url) return reply.status(400).send({ error: 'URL required' });

    const cacheKey = `meta:${Buffer.from(url).toString('base64').slice(0, 40)}`;
    const cached = await cacheGet<any>(cacheKey);
    if (cached) return reply.send(cached);

    try {
      const meta = await extractMetadata(url);
      await cacheSet(cacheKey, meta, 3600);
      reply.send(meta);
    } catch (e: any) {
      reply.status(500).send({ error: 'Metadata failed: ' + e.message });
    }
  });

  // ═════════════════════════════════════════════════════════════════════════
  // GET /api/media/youtube-stream?id=VIDEO_ID — Streaming Proxy (v9 July 2026)
  // Brain Phase 1.2: registered ONLY in non-compliant builds.
  // ═════════════════════════════════════════════════════════════════════════
  //
  // PROBLEM: googlevideo URLs are IP-bound. yt-dlp extracts a URL containing
  // &ip=<railway_ip>. When AVPlayer on iPhone requests from a different IP,
  // YouTube returns 403 → AVPlayer fails with -11828.
  //
  // SOLUTION: backend acts as a reverse proxy. iPhone requests this endpoint,
  // backend extracts the googlevideo URL (IP-bound to Railway), then fetches
  // the video from googlevideo (IP matches → 200 OK), and streams it back
  // to iPhone. AVPlayer sees a Railway URL, not a googlevideo URL.
  //
  // Supports HTTP Range requests for seeking — passes Range header through
  // to googlevideo and passes Content-Range back to client.
  //
  // Cache: extraction results cached 1hr (googlevideo URLs live ~6hrs).
  // The proxy itself doesn't cache video data (would consume too much RAM).
  //
  // Auth: requires JWT (prevents anonymous abuse).
  // Rate limit: 20 requests/minute (each request = 1 yt-dlp extraction).

  // v9.3: auth via query param (?token=JWT) — AVPlayer can't send headers reliably
  // v9.4: override security headers — CORP same-origin blocks AVPlayer cross-origin
  if (!COMPLIANT) {
  fastify.get('/media/youtube-stream', {
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } }
  }, async (request: any, reply: any) => {
    // 🔧 v9.4: override restrictive security headers for this endpoint.
    // The global securityHeaders hook sets:
    //   Cross-Origin-Resource-Policy: same-origin
    //   Cross-Origin-Embedder-Policy: require-corp
    // These block AVPlayer (which makes cross-origin requests from the iOS
    // app to the backend). Without overriding, AVPlayer gets -1008.
    reply.header('Cross-Origin-Resource-Policy', 'cross-origin');
    reply.header('Cross-Origin-Embedder-Policy', 'unsafe-none');
    reply.header('Access-Control-Allow-Origin', '*');
    reply.header('Access-Control-Allow-Headers', 'Range, Content-Type');
    reply.header('Access-Control-Expose-Headers', 'Content-Range, Content-Length, Accept-Ranges');

    const { id, token } = request.query as any;
    if (!id || typeof id !== 'string' || id.length > 20) {
      return reply.status(400).send({ error: 'Valid video ID required' });
    }
    // Auth via query param (AVPlayer drops Authorization headers on Range requests)
    if (!token || typeof token !== 'string') {
      return reply.status(401).send({ error: 'Token required' });
    }
    try {
      const payload = fastify.jwt.verify(token);
      (request as any).user = payload;
    } catch {
      return reply.status(401).send({ error: 'Invalid token' });
    }

    // ── 1. Extract googlevideo URL (cached) ──────────────────────────
    const cacheKey = `yt:stream:${id}`;
    let streamInfo: any = await cacheGet<any>(cacheKey);
    if (!streamInfo) {
      try {
        streamInfo = await extractYouTubeStream(id);
        await cacheSet(cacheKey, streamInfo, EXTRACT_CACHE_TTL);
      } catch (e: any) {
        console.error('[youtube-stream] extract error', e.message);
        return reply.status(500).send({ error: 'Extract failed: ' + e.message });
      }
    }

    const upstreamUrl = streamInfo.streamURL;
    if (!upstreamUrl) {
      return reply.status(500).send({ error: 'No stream URL available' });
    }

    // ── 2. Fetch from googlevideo (IP-bound to Railway = matches) ─────
    // Pass through Range header for seeking support.
    const rangeHeader = request.headers.range;
    const upstreamHeaders: any = {
      'User-Agent': UPSTREAM_USER_AGENT,
      'Referer': 'https://www.youtube.com/',
      'Origin': 'https://www.youtube.com',
    };
    if (rangeHeader) {
      upstreamHeaders['Range'] = rangeHeader;
    }

    try {
      const upstreamRes = await fetch(upstreamUrl, { headers: upstreamHeaders, redirect: 'follow' });

      if (!upstreamRes.ok && upstreamRes.status !== 206) {
        console.error('[youtube-stream] upstream error', upstreamRes.status);
        return reply.status(502).send({ error: `Upstream returned ${upstreamRes.status}` });
      }

      // ── 3. Stream upstream response back to client ─────────────────
      // 🔧 v9.2: replaced Readable.fromWeb with manual pump.
      // Readable.fromWeb doesn't work reliably on Railway's Node.js,
      // causing -1008 'Ресурс недоступен' on AVPlayer.
      // Manual pump using reader.read() + raw.write() works everywhere.
      if (upstreamRes.body) {
        const reader = upstreamRes.body.getReader();
        const raw = reply.raw;
        const respHeaders: Record<string, string> = {
          'Content-Type': upstreamRes.headers.get('content-type') || 'video/mp4',
          'Accept-Ranges': 'bytes',
          'Cache-Control': 'public, max-age=3600',
        };
        const cl = upstreamRes.headers.get('content-length');
        if (cl) respHeaders['Content-Length'] = cl;
        const cr = upstreamRes.headers.get('content-range');
        if (cr) respHeaders['Content-Range'] = cr;
        raw.writeHead(upstreamRes.status, respHeaders);

        const pump = async () => {
          try {
            while (true) {
              const { done, value } = await reader.read();
              if (done) break;
              if (!raw.destroyed) raw.write(Buffer.from(value));
            }
            raw.end();
          } catch (err: any) {
            console.error('[youtube-stream] pump error', err.message);
            if (!raw.destroyed) raw.end();
          }
        };
        pump();
        return reply;
      } else {
        return reply.send(Buffer.alloc(0));
      }
    } catch (e: any) {
      console.error('[youtube-stream] proxy error', e.message);
      return reply.status(500).send({ error: 'Stream proxy failed: ' + e.message });
    }
  });
  } // end if (!COMPLIANT) — /media/youtube-stream

  // ═════════════════════════════════════════════════════════════════════════
  // GET /api/media/youtube-player?id=VIDEO_ID — Hosted IFrame Player (v11)
  // Brain Phase 2: official YouTube controls. ALWAYS registered (compliant).
  // ═════════════════════════════════════════════════════════════════════════
  //
  // Serves a static HTML page that uses YouTube IFrame API.
  // iOS WKWebView loads this URL (not youtube.com/embed/ directly).
  //
  // The page has a REAL origin (https://plink-backend...) so:
  //   - IFrame API postMessage works (no 152-4)
  //   - YouTube's WKWebView detection doesn't run in our page context (no 153)
  //   - No bot check (we're not loading youtube.com directly)
  //
  // No auth required — video ID is public. Rate limited to prevent abuse.

  fastify.get('/media/youtube-player', {
    config: { rateLimit: { max: 60, timeWindow: '1 minute' } }
  }, async (request: any, reply: any) => {
    const { id } = request.query as any;
    if (!id || typeof id !== 'string' || id.length > 20) {
      return reply.status(400).send('Valid video ID required');
    }

    // Override security headers for HTML page
    reply.header('Content-Type', 'text/html; charset=utf-8');
    reply.header('Cross-Origin-Resource-Policy', 'cross-origin');
    reply.header('Cross-Origin-Embedder-Policy', 'unsafe-none');
    reply.header('Access-Control-Allow-Origin', '*');
    // 🔧 v18.1: override CSP — allow youtube-nocookie.com in frame-src
    reply.header('Content-Security-Policy',
      "default-src * 'unsafe-inline' 'unsafe-eval' data: blob:; " +
      "script-src * 'unsafe-inline' 'unsafe-eval'; " +
      "style-src * 'unsafe-inline'; " +
      "img-src * data: blob:; " +
      "media-src *; " +
      "connect-src * wss:; " +
      "frame-src *; " +
      "child-src *;");

    const html = youtubePlayerHTML(id);
    return reply.send(html);
  });

  // ═════════════════════════════════════════════════════════════════════════
  // GET /api/media/youtube-embed?id=VIDEO_ID — Full Embed Proxy (v12)
  // Brain Phase 1.2: registered ONLY in non-compliant builds.
  // ═════════════════════════════════════════════════════════════════════════
  //
  // v12: backend fetches the ENTIRE youtube.com/embed/ page and serves it.
  // WKWebView loads this from backend URL (not youtube.com) → no 153.
  // YouTube's player JS runs directly in the page → no iframe → no bot check.
  // Only youtube.com requests from WKWebView are static JS/CSS (not bot-checked).
  //
  // This is fundamentally different from v11:
  //   v11: our HTML + IFrame API → creates iframe to youtube.com → bot check
  //   v12: YouTube's OWN embed HTML → player runs directly → NO iframe request

  if (!COMPLIANT) {
  fastify.get('/media/youtube-embed', {
    config: { rateLimit: { max: 30, timeWindow: '1 minute' } }
  }, async (request: any, reply: any) => {
    const { id } = request.query as any;
    if (!id || typeof id !== 'string' || id.length > 20) {
      return reply.status(400).send('Valid video ID required');
    }

    // Override security headers
    reply.header('Content-Type', 'text/html; charset=utf-8');
    reply.header('Cross-Origin-Resource-Policy', 'cross-origin');
    reply.header('Cross-Origin-Embedder-Policy', 'unsafe-none');
    reply.header('Access-Control-Allow-Origin', '*');
    // Allow YouTube's scripts, styles, images, and media
    reply.header('Content-Security-Policy',
      "default-src * 'unsafe-inline' 'unsafe-eval' data: blob:; " +
      "script-src * 'unsafe-inline' 'unsafe-eval'; " +
      "style-src * 'unsafe-inline'; " +
      "img-src * data: blob:; " +
      "media-src *; " +
      "connect-src * wss:; " +
      "frame-src *;");

    try {
      // Cache the proxied page for 1 hour
      const cacheKey = `yt:embed:${id}`;
      let html = await cacheGet<string>(cacheKey);
      if (!html) {
        html = await proxyYouTubeEmbed(id);
        await cacheSet(cacheKey, html, EXTRACT_CACHE_TTL);
      }
      return reply.send(html);
    } catch (e: any) {
      console.error('[youtube-embed] proxy error', e.message);
      return reply.status(500).send('Embed proxy failed: ' + e.message);
    }
  });
  } // end if (!COMPLIANT) — /media/youtube-embed
}
