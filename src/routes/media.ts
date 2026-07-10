// src/routes/media.ts — v104: only search/trending/categories (YouTube Data API v3)
// Extraction routes (/extract, /extract-url, /metadata, /youtube-stream,
// /youtube-player, /youtube-embed) REMOVED — playback now uses /api/media/stream
// HLS-only relay in src/index.ts. See handoff bundle file 06a for context.
import { cacheGet, cacheSet } from '../config/redis.js';

const EXTRACT_CACHE_TTL = 3600; // 1 час — для search/trending кеша

export default async function mediaRoutes(fastify, _options) {
  const YOUTUBE_API_KEY = process.env.YOUTUBE_API_KEY;

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

    const url = new URL('https://www.googleapis.com/youtube/v3/search');
    url.searchParams.set('part', 'snippet');
    url.searchParams.set('q', q);
    url.searchParams.set('type', 'video');
    url.searchParams.set('maxResults', String(limit));
    url.searchParams.set('key', YOUTUBE_API_KEY);

    try {
      const resp = await fetch(url.toString());
      if (!resp.ok) {
        const errText = await resp.text();
        console.error('YouTube API error', resp.status, errText);
        return reply.status(resp.status).send({ error: 'YouTube API error' });
      }
      const data: any = await resp.json();

      const results = (data.items || [])
        .filter((item: any) => item.id?.videoId)
        .map((item: any) => {
          const videoId = item.id.videoId;
          return {
            id: videoId,
            title: item.snippet?.title || '',
            channel: item.snippet?.channelTitle || '',
            thumbnailURL: item.snippet?.thumbnails?.medium?.url ||
                          item.snippet?.thumbnails?.default?.url || null,
            duration: null,
            // 🔧 FIX: iOS YouTubeSearchResult requires `url` field — without it,
            // Decodable fails silently and the user sees empty search results.
            // Return watch URL so iOS can pass it directly to RoomSetupView.
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

    // Use videos.list with chart=mostPopular to get trending videos
    const url = new URL('https://www.googleapis.com/youtube/v3/videos');
    url.searchParams.set('part', 'snippet,contentDetails');
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
          let duration: number | null = null;
          if (item.contentDetails?.duration) {
            const match = item.contentDetails.duration.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
            if (match) {
              const hours = parseInt(match[1] || '0');
              const mins = parseInt(match[2] || '0');
              const secs = parseInt(match[3] || '0');
              duration = hours * 3600 + mins * 60 + secs;
            }
          }
          return {
            id: videoId,
            title: item.snippet?.title || '',
            channel: item.snippet?.channelTitle || '',
            thumbnailURL: item.snippet?.thumbnails?.medium?.url ||
                          item.snippet?.thumbnails?.high?.url ||
                          item.snippet?.thumbnails?.default?.url || null,
            duration: duration,
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
}
