// src/index.ts — Pack 6: добавлена регистрация AI routes
import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import rateLimit from '@fastify/rate-limit';
import websocket from '@fastify/websocket';
import * as Sentry from '@sentry/node';
import { config } from './config/index.js';
import { prisma } from './config/db.js';
import { checkRedis } from './config/redis.js';
import { authenticate } from './middleware/auth.js';
import { securityHeaders } from './middleware/security.js';
import { setupWebSocketHandler } from './websocket/ws-handler.js';
import { register } from './services/metrics.js';
import { initTelemetry } from './services/telemetry.js';
import authRoutes from './routes/auth.js';
import roomRoutes from './routes/rooms.js';
import friendRoutes from './routes/friends.js';
import messageRoutes from './routes/messages.js';
import profileRoutes from './routes/profile.js';
import mediaRoutes from './routes/media.js';
import billingRoutes from './routes/billing.js';
import gdprRoutes from './routes/gdpr.js';
import featureFlagRoutes from './routes/featureFlags.js';
import aiRoutes from './routes/ai.js';  // ← Pack 6
import { alertCritical } from './utils/alerting.js';
import { pipeline } from 'node:stream';
import { Readable } from 'node:stream';

initTelemetry(process.env.OTEL_ENDPOINT);

if (config.SENTRY_DSN) {
  Sentry.init({
    dsn: config.SENTRY_DSN,
    environment: config.NODE_ENV,
    tracesSampleRate: config.isProduction ? 0.1 : 1.0,
  });
  console.log('✅ Sentry initialized');
}

const fastify = Fastify({
  logger: {
    level: config.isProduction ? 'info' : 'debug',
    transport: config.isProduction ? undefined : { target: 'pino-pretty' },
    redact: ['req.headers.authorization', 'req.body.password', '*.password', 'req.body.receipt'],
  },
});

fastify.decorate('prisma', prisma);

await fastify.register(cors, { 
  origin: config.CORS_ORIGIN, 
  credentials: true,
  methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Authorization', 'Content-Type', 'X-Request-ID'],
});
await fastify.register(jwt, { 
  secret: config.JWT_SECRET,
  sign: { algorithm: 'HS256', iss: 'plink', aud: 'plink-ios' },
});
await fastify.register(rateLimit, {
  global: false,
  max: 100,
  timeWindow: '1 minute',
  cache: 10000,
  ban: 5,
});
await fastify.register(websocket, { options: { maxPayload: 1048576 } });

fastify.decorate('authenticate', authenticate);
fastify.addHook('onRequest', securityHeaders);

// ═══════════════════════════════════════════════════════════════════════════
// v95: Server-Side Extraction + StreamRelay
// AVPlayer sends: GET /api/media/stream?videoId=ID&token=JWT
// Backend extracts googlevideo URL (server IP = extraction IP = streaming IP)
// then pipes bytes to AVPlayer. NO IP mismatch → NO 403.
// Also supports b64url/url for backward compat.
// ═══════════════════════════════════════════════════════════════════════════
const PIPED_INSTANCES = [
  'https://pipedapi.kavin.rocks',
  'https://pipedapi.leptons.xyz',
  'https://pipedapi.r4fo.com',
];

async function extractStreamURL(videoId: string): Promise<string> {
  // Try Piped API first (fastest)
  for (const instance of PIPED_INSTANCES) {
    try {
      console.log('[Extract] Trying Piped:', instance);
      const res = await fetch(`${instance}/streams/${videoId}`, {
        signal: AbortSignal.timeout(8000),
      });
      if (!res.ok) continue;
      const data: any = await res.json();

      // Priority 1: muxed MP4 (itag 22=720p, 18=360p)
      if (data.videoStreams && Array.isArray(data.videoStreams)) {
        const muxed = data.videoStreams.filter((s: any) => !s.videoOnly);
        const best = muxed.find((s: any) => s.itag === 22)
                   || muxed.find((s: any) => s.itag === 18)
                   || muxed[0];
        if (best && best.url) {
          console.log('[Extract] ✅ Piped muxed MP4 itag:', best.itag);
          return best.url;
        }
      }

      // Priority 2: HLS
      if (data.hls) {
        console.log('[Extract] ✅ Piped HLS');
        return data.hls;
      }
    } catch (e: any) {
      console.log('[Extract] Piped failed:', e.message);
    }
  }

  // Fallback: yt-dlp (if available on Railway)
  try {
    console.log('[Extract] Trying yt-dlp...');
    const { execSync } = await import('child_process');
    const output = execSync(
      `yt-dlp -f "best[ext=mp4][vcodec!=none][acodec!=none]/best[vcodec!=none][acodec!=none]" -g "https://www.youtube.com/watch?v=${videoId}"`,
      { timeout: 15000, encoding: 'utf-8' }
    ).trim();
    if (output && output.includes('http')) {
      console.log('[Extract] ✅ yt-dlp URL:', output.substring(0, 80));
      return output;
    }
  } catch (e: any) {
    console.log('[Extract] yt-dlp failed:', e.message?.substring(0, 100));
  }

  throw new Error('All extraction methods failed');
}

// Cache for extracted URLs (5 min TTL — googlevideo URLs live ~6h)
const urlCache = new Map<string, { url: string; expires: number }>();

fastify.get('/api/media/stream', {
  config: { rateLimit: { max: 60, timeWindow: '1 minute' } }
}, async (request: any, reply: any) => {
  console.log('[Relay] ====== StreamRelay request received ======');

  // Override security headers for AVPlayer
  reply.header('Cross-Origin-Resource-Policy', 'cross-origin');
  reply.header('Cross-Origin-Embedder-Policy', 'unsafe-none');
  reply.header('Access-Control-Allow-Origin', '*');
  reply.header('Access-Control-Allow-Headers', 'Range, Content-Type');
  reply.header('Access-Control-Expose-Headers', 'Content-Range, Content-Length, Accept-Ranges');

  // Parse raw query string
  const rawQuery = request.url.split('?')[1] || '';
  const videoIdParam = new URLSearchParams(rawQuery).get('videoId');
  const b64urlParam = new URLSearchParams(rawQuery).get('b64url');
  const urlParam = new URLSearchParams(rawQuery).get('url');
  const tokenParam = new URLSearchParams(rawQuery).get('token');
  const b64cookiesParam = new URLSearchParams(rawQuery).get('b64cookies');

  console.log('[Relay] videoId:', videoIdParam || 'none', 'b64url:', !!b64urlParam, 'b64cookies:', !!b64cookiesParam);

  if (!tokenParam) return reply.status(401).send({ error: 'Token required' });
  try {
    fastify.jwt.verify(tokenParam);
  } catch {
    return reply.status(401).send({ error: 'Invalid token' });
  }

  // v96: Decode cookies from base64
  let cookieHeader = '';
  if (b64cookiesParam) {
    try {
      cookieHeader = Buffer.from(b64cookiesParam, 'base64').toString('utf-8');
      console.log('[Relay] ✅ Decoded cookies, length:', cookieHeader.length);
    } catch {
      console.log('[Relay] ⚠️ Failed to decode cookies');
    }
  }

  // Determine target URL
  let targetUrl: string | null = null;

  // Mode 1: videoId — server-side extraction (v95, solves IP mismatch)
  if (videoIdParam) {
    // Check cache
    const cached = urlCache.get(videoIdParam);
    if (cached && cached.expires > Date.now()) {
      targetUrl = cached.url;
      console.log('[Relay] ✅ Using cached URL for videoId:', videoIdParam);
    } else {
      try {
        console.log('[Relay] Extracting stream URL for videoId:', videoIdParam);
        targetUrl = await extractStreamURL(videoIdParam);
        // Cache for 5 minutes
        urlCache.set(videoIdParam, { url: targetUrl, expires: Date.now() + 300000 });
        console.log('[Relay] ✅ Extracted + cached URL');
      } catch (e: any) {
        console.error('[Relay] ❌ Extraction failed:', e.message);
        return reply.status(502).send({ error: 'Extraction failed: ' + e.message });
      }
    }
  }
  // Mode 2: b64url (backward compat)
  else if (b64urlParam) {
    try {
      targetUrl = Buffer.from(b64urlParam, 'base64').toString('utf-8');
      console.log('[Relay] Decoded b64url, len:', targetUrl.length);
    } catch {
      return reply.status(400).send({ error: 'Invalid base64' });
    }
  }
  // Mode 3: raw url (backward compat)
  else if (urlParam) {
    targetUrl = urlParam;
  } else {
    return reply.status(400).send({ error: 'videoId, b64url, or url required' });
  }

  if (!targetUrl) {
    return reply.status(500).send({ error: 'No stream URL' });
  }

  console.log('[Relay] Target:', targetUrl.substring(0, 100) + '...');

  try {
    const upstreamHeaders: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
      'Referer': 'https://www.youtube.com/',
      'Origin': 'https://www.youtube.com',
    };
    // v96: Add cookies from client (Authenticated Proxy)
    if (cookieHeader) {
      upstreamHeaders['Cookie'] = cookieHeader;
      console.log('[Relay] ✅ Sending cookies to YouTube CDN');
    }
    if (request.headers.range) upstreamHeaders['Range'] = request.headers.range;

    console.log('[Relay] Fetching from YouTube CDN...');
    const upstreamRes = await fetch(targetUrl, { headers: upstreamHeaders, redirect: 'follow' });

    console.log('[Relay] Upstream status:', upstreamRes.status, 'Content-Length:', upstreamRes.headers.get('content-length'));

    if (!upstreamRes.ok && upstreamRes.status !== 206) {
      const errorBody = await upstreamRes.text().catch(() => 'unreadable');
      console.error('[Relay] ❌ Upstream error:', upstreamRes.status, errorBody.substring(0, 200));
      // If 403, invalidate cache (URL may be expired/IP-bound)
      if (upstreamRes.status === 403 && videoIdParam) {
        urlCache.delete(videoIdParam);
        console.log('[Relay] Cache invalidated for videoId:', videoIdParam);
      }
      return reply.status(upstreamRes.status).send({ error: `YouTube ${upstreamRes.status}` });
    }

    if (upstreamRes.body) {
      const nodeStream = Readable.fromWeb(upstreamRes.body);
      reply.hijack();
      const raw = reply.raw;
      const respHeaders: Record<string, string> = {
        'Content-Type': upstreamRes.headers.get('content-type') || 'video/mp4',
        'Accept-Ranges': 'bytes',
      };
      const cl = upstreamRes.headers.get('content-length');
      if (cl) respHeaders['Content-Length'] = cl;
      const cr = upstreamRes.headers.get('content-range');
      if (cr) respHeaders['Content-Range'] = cr;
      raw.writeHead(upstreamRes.status, respHeaders);

      pipeline(nodeStream, raw, (err: any) => {
        if (err) {
          console.error('[Relay] ❌ Pipeline error:', err.message);
          if (!raw.destroyed) raw.destroy();
        } else {
          console.log('[Relay] ✅ Pipeline complete');
        }
      });
      return;
    } else {
      return reply.send(Buffer.alloc(0));
    }
  } catch (e: any) {
    console.error('[Relay] ❌ Error:', e.message);
    return reply.status(502).send({ error: 'Stream relay failed: ' + e.message });
  }
});

// 404 RADAR
fastify.setNotFoundHandler((request: any, reply: any) => {
  console.log(`[404 RADAR] Missed: ${request.method} ${request.url.substring(0, 200)}`);
  reply.code(404).send({ error: 'Not Found' });
});

await fastify.register(authRoutes, { prefix: '/api' });
await fastify.register(roomRoutes, { prefix: '/api' });
await fastify.register(friendRoutes, { prefix: '/api' });
await fastify.register(messageRoutes, { prefix: '/api' });
await fastify.register(profileRoutes, { prefix: '/api' });
await fastify.register(mediaRoutes, { prefix: '/api' });
await fastify.register(billingRoutes, { prefix: '/api' });
await fastify.register(gdprRoutes, { prefix: '/api' });
await fastify.register(featureFlagRoutes, { prefix: '/api' });
await fastify.register(aiRoutes, { prefix: '/api' });  // ← Pack 6

setupWebSocketHandler(fastify.websocketServer, prisma, fastify);

// 🔧 FIX: Register /ws and /ws/room/:id as Fastify websocket routes.
// Without this, Fastify returns 404 for the HTTP upgrade request and
// iOS WS client can't connect → RoomView hangs on "loading" forever.
// @fastify/websocket plugin auto-routes upgrade requests to these handlers.
// The actual connection logic is in setupWebSocketHandler (raw 'connection'
// event on fastify.websocketServer). These route handlers are no-ops —
// they exist only so Fastify allows the WebSocket upgrade.
fastify.get('/ws', { websocket: true }, async () => {});
fastify.get('/ws/room/:id', { websocket: true }, async () => {});

fastify.get('/health', async () => {
  const db = await checkDatabase();
  const redis = await checkRedis();
  return {
    status: db ? 'ok' : 'degraded',
    timestamp: Date.now(),
    uptime: process.uptime(),
    version: '1.6.1-v10.2',
    environment: config.NODE_ENV,
    services: {
      database: db ? 'up' : 'down',
      redis: redis ? 'up' : (config.REDIS_URL ? 'down' : 'not_configured'),
      yt_dlp: 'available',
      sentry: config.SENTRY_DSN ? 'configured' : 'not_configured',
      ai: process.env.OPENROUTER_API_KEY ? 'configured' : 'not_configured',
    },
    memory: process.memoryUsage(),
  };
});

fastify.get('/metrics', async (req, reply) => {
  reply.type('text/plain').send(await register.metrics());
});

async function checkDatabase(): Promise<boolean> {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return true;
  } catch {
    return false;
  }
}

fastify.setErrorHandler((error: any, request: any, reply: any) => {
  if (error.statusCode >= 500) {
    Sentry.captureException(error);
    alertCritical('Server error', error as Error);
  }
  reply.status(error.statusCode || 500).send({
    error: error.message || 'Internal Server Error',
    statusCode: error.statusCode || 500,
    requestId: request.id,
  });
});

const start = async () => {
  try {
    await fastify.listen({ port: config.PORT, host: '0.0.0.0' });
    console.log(`🚀 Plink backend v1.6.0 on port ${config.PORT} [${config.NODE_ENV}]`);
    console.log(`🤖 AI: /api/ai/chat | /api/ai/recommend`);

    // v94.14: Рентген роутов — выводим все зарегистрированные пути
    await fastify.ready();
    console.log('📋 REGISTERED ROUTES:');
    console.log(fastify.printRoutes());
  } catch (err) {
    Sentry.captureException(err);
    await alertCritical('Backend failed to start', err as Error);
    fastify.log.error(err);
    process.exit(1);
  }
};

const shutdown = async (signal: string) => {
  console.log(`\n${signal} received, shutting down...`);
  await fastify.close();
  await prisma.$disconnect();
  process.exit(0);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('uncaughtException', async (err) => {
  Sentry.captureException(err);
  await alertCritical('Uncaught exception', err);
});
process.on('unhandledRejection', async (reason) => {
  Sentry.captureException(reason as Error);
  await alertCritical('Unhandled rejection', reason as Error);
});

start();
