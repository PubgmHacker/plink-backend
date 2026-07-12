// src/config/index.ts — Stabilize v2: typed config, aud allowlist, weak-secret guard
function required(key: string): string {
  const val = process.env[key];
  if (!val) throw new Error(`Missing env: ${key}`);
  return val;
}

function parseAudiences(raw: string | undefined): string[] {
  if (!raw) return ['plink-ios'];
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

function parseCorsOrigin(raw: string | undefined): string | string[] {
  if (!raw || raw === '*') {
    // §2: "*" with credentials is forbidden in production. We allow it only
    // for development to keep local iteration fast; production startup will
    // reject it (see assertProductionInvariants below).
    return '*';
  }
  // Support "app://plink" and "null" as valid origins (iOS native app sends
  // no Origin header, but if it does, it's "null" or "app://bundle.id").
  // The keyword `native` expands to a small allowlist of native app origins.
  const expanded = raw
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
    .flatMap((s) => {
      if (s === 'native') {
        // Common iOS native origins + localhost for simulator testing.
        return [
          'null',                        // iOS WKWebView may send Origin: null
          'app://plink',                 // Plink custom scheme (if used)
          'capacitor://localhost',       // Capacitor app
          'ionic://localhost',           // Ionic app
          'http://localhost',            // iOS Simulator (HTTP)
          'http://localhost:8080',       // iOS Simulator (alt port)
          'https://localhost',           // iOS Simulator (HTTPS)
        ];
      }
      return [s];
    });
  return expanded;
}

const jwtSecret = process.env.JWT_SECRET || 'dev-secret-change-me';

export const config = {
  DATABASE_URL: process.env.DATABASE_URL || required('DATABASE_URL'),
  JWT_SECRET: jwtSecret,
  JWT_ISSUER: process.env.JWT_ISSUER || 'plink',
  JWT_AUDIENCES: parseAudiences(process.env.JWT_AUDIENCES),
  JWT_REFRESH_SECRET: process.env.JWT_REFRESH_SECRET || 'dev-refresh-secret-change-me',
  CORS_ORIGIN: parseCorsOrigin(process.env.CORS_ORIGIN),

  PORT: parseInt(process.env.PORT || '8080'),

  REDIS_URL: process.env.REDIS_URL || '',
  SENTRY_DSN: process.env.SENTRY_DSN || '',
  SLACK_WEBHOOK_URL: process.env.SLACK_WEBHOOK_URL || '',

  // Token TTLs
  ACCESS_TOKEN_TTL: process.env.ACCESS_TOKEN_TTL || '7d',
  REFRESH_TOKEN_TTL_DAYS: parseInt(process.env.REFRESH_TOKEN_TTL_DAYS || '90'),

  // Realtime ticket endpoint (§2): short-lived, single-use nonce
  REALTIME_TICKET_TTL_SEC: parseInt(process.env.REALTIME_TICKET_TTL_SEC || '60'),

  // Signed media URL TTL (§6): 60–300 seconds
  SIGNED_MEDIA_URL_TTL: parseInt(process.env.SIGNED_MEDIA_URL_TTL || '120'),

  // Feature flags — see rollout plan §15
  APP_STORE_COMPLIANT: process.env.APP_STORE_COMPLIANT !== 'false',
  ENABLE_LEGACY_STREAM_RELAY: process.env.ENABLE_LEGACY_STREAM_RELAY === 'true',
  REALTIME_PROTOCOL_V2: process.env.REALTIME_PROTOCOL_V2 !== 'false',
  NATIVE_PLAYER_V2: process.env.NATIVE_PLAYER_V2 !== 'false',
  LIVEKIT_SFU: process.env.LIVEKIT_SFU === 'true',
  WATCH_SCREEN_V2: process.env.WATCH_SCREEN_V2 === 'true',

  // LiveKit (Stage 9)
  LIVEKIT_URL: process.env.LIVEKIT_URL || '',
  LIVEKIT_API_KEY: process.env.LIVEKIT_API_KEY || '',
  LIVEKIT_API_SECRET: process.env.LIVEKIT_API_SECRET || '',

  NODE_ENV: process.env.NODE_ENV || 'development',
  isProduction: process.env.NODE_ENV === 'production',
};

/**
 * §2: production startup must refuse to boot on weak/default secrets and on
 * CORS "*" with credentials. Called from app.ts during bootstrap.
 *
 * Brain Phase 1.1: missing/unknown NODE_ENV is fatal outside tests.
 */
export function assertProductionInvariants(): void {
  // Brain Phase 1.1: NODE_ENV must be explicitly set to 'production' or
  // 'development' (or 'test'). Missing/unknown values are fatal outside tests.
  const nodeEnv = process.env.NODE_ENV;
  if (!nodeEnv) {
    if (process.env.JEST_WORKER_ID || process.env.NODE_ENV === 'test') return;
    throw new Error(
      'FATAL: NODE_ENV is not set. Must be "production", "development", or "test".',
    );
  }
  const known = new Set(['production', 'development', 'test', 'staging']);
  if (!known.has(nodeEnv)) {
    throw new Error(
      `FATAL: NODE_ENV="${nodeEnv}" is not recognized. Use one of: production, development, test, staging.`,
    );
  }

  if (!config.isProduction) return;

  const weakSecrets = new Set([
    'dev-secret-change-me',
    'dev-refresh-secret-change-me',
    'your-super-secret-key-change-me',
    'replace-with-strong-32-char-min-secret',
    'changeme',
    'secret',
  ]);
  if (weakSecrets.has(config.JWT_SECRET) || config.JWT_SECRET.length < 32) {
    throw new Error(
      `FATAL: JWT_SECRET is weak or default in production (len=${config.JWT_SECRET.length}). ` +
        `Rotate immediately and set JWT_SECRET to a >=32-char random string.`,
    );
  }
  if (config.CORS_ORIGIN === '*') {
    throw new Error(
      'FATAL: CORS_ORIGIN="*" with credentials is forbidden in production. ' +
        'Set an explicit allowlist (comma-separated origins).',
    );
  }
  if (config.JWT_AUDIENCES.length === 0) {
    throw new Error('FATAL: JWT_AUDIENCES must contain at least one audience in production.');
  }
  // Brain Phase 1.1: APP_STORE_COMPLIANT must be true in production.
  if (!config.APP_STORE_COMPLIANT) {
    throw new Error(
      'FATAL: APP_STORE_COMPLIANT=false is forbidden in production. ' +
        'App Store builds must not register extraction/proxy routes.',
    );
  }
}
