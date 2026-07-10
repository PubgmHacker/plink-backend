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
// v104: HLS-only Safe Relay (StreamRelay)
// ═══════════════════════════════════════════════════════════════════════════
// v90-v103 history: backend extraction (yt-dlp/Piped/innertube) all blocked
// on Railway IP. Strip-ip breaks signature. WebView extraction unreliable.
//
// v104 solution: backend is a DUMB PIPE for HLS manifests only.
//   - iOS extracts hlsManifestUrl via URLSession (iPhone IP, not blocked)
//   - iOS sends b64url to backend
//   - Backend validates URL is HTTPS + trusted host + HLS path marker
//   - Backend fetches manifest (no mutation of signed URL)
//   - Backend pipes manifest bytes to AVPlayer
//   - AVPlayer fetches segments DIRECTLY from iPhone IP (manifest has
//     absolute segment URLs that are IP-bound to iPhone — extraction IP
//     matches playback IP → 200 OK)
//
// Security:
//   - HTTPS only (no HTTP, no IP literals, no credentials, no custom ports)
//   - Trusted host allowlist: youtube.com / googlevideo.com (and subdomains)
//   - HLS path markers required: /manifest/hls, hls_playlist, .m3u8
//   - Redirect validation: every redirect re-checked against allowlist
//   - Size limit: manifest ≤ 2MB
//   - Content-Type validation: only mpegurl or application/vnd.apple
//   - No URL mutation (signed URL preserved exactly)
//   - No logging of token/URL
// ═══════════════════════════════════════════════════════════════════════════

const HLS_PATH_MARKERS = ['/manifest/hls', 'hls_playlist', '.m3u8'];

function decodeBase64Strict(value: string): string {
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(value) || value.length > 16_384) {
    throw new Error('Invalid base64');
  }
  return Buffer.from(value, 'base64').toString('utf8');
}

function assertTrustedHlsUrl(value: string): URL {
  const url = new URL(value);
  if (url.protocol !== 'https:' || url.username || url.password || url.port) {
    throw new Error('Only HTTPS manifest URLs are allowed');
  }
  const host = url.hostname.toLowerCase();
  const trusted = host === 'youtube.com' || host.endsWith('.youtube.com') ||
                  host === 'googlevideo.com' || host.endsWith('.googlevideo.com');
  if (!trusted) throw new Error('Untrusted manifest host');
  if (/^\d{1,3}(\.\d{1,3}){3}$/.test(host) || host === 'localhost') {
    throw new Error('IP literals are not allowed');
  }
  const path = url.pathname.toLowerCase();
  if (!HLS_PATH_MARKERS.some(marker => path.includes(marker))) {
    throw new Error('Only HLS manifests are allowed');
  }
  return url;
}

async function fetchTrustedManifest(initial: URL): Promise<Response> {
  let current = initial;
  for (let attempt = 0; attempt < 4; attempt++) {
    const response = await fetch(current, {
      redirect: 'manual',
      headers: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15',
        'Referer': 'https://www.youtube.com/'
      },
      signal: AbortSignal.timeout(10_000)
    });
    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = response.headers.get('location');
      if (!location) throw new Error('Invalid redirect');
      current = assertTrustedHlsUrl(new URL(location, current).toString());
      continue;
    }
    return response;
  }
  throw new Error('Too many redirects');
}

fastify.get('/api/media/stream', {
  config: { rateLimit: { max: 60, timeWindow: '1 minute' } }
}, async (request: any, reply: any) => {
  reply.header('Cross-Origin-Resource-Policy', 'cross-origin');
  reply.header('Cross-Origin-Embedder-Policy', 'unsafe-none');
  reply.header('Cache-Control', 'private, no-store');

  const { b64url, token } = request.query as { b64url?: string; token?: string };
  if (!token) return reply.status(401).send({ error: 'Token required' });
  try { fastify.jwt.verify(token); }
  catch { return reply.status(401).send({ error: 'Invalid token' }); }
  if (!b64url) return reply.status(400).send({ error: 'b64url required' });

  try {
    const manifestURL = assertTrustedHlsUrl(decodeBase64Strict(b64url));
    const upstream = await fetchTrustedManifest(manifestURL);
    if (!upstream.ok) {
      return reply.status(502).send({ error: `Manifest upstream ${upstream.status}` });
    }
    const type = upstream.headers.get('content-type')?.toLowerCase() ?? '';
    if (!type.includes('mpegurl') && !type.includes('application/vnd.apple')) {
      return reply.status(502).send({ error: 'Upstream is not an HLS manifest' });
    }
    const body = await upstream.arrayBuffer();
    if (body.byteLength > 2_000_000) {
      return reply.status(502).send({ error: 'Manifest too large' });
    }
    reply.type(type || 'application/vnd.apple.mpegurl');
    return reply.send(Buffer.from(body));
  } catch (error: any) {
    request.log.warn({ message: error.message }, 'Rejected media relay request');
    return reply.status(400).send({ error: error.message || 'Invalid relay request' });
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
