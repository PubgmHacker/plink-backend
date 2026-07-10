// src/config/index.ts — v104: production secrets enforcement
function required(key: string): string {
  const val = process.env[key];
  if (!val) throw new Error(`Missing env: ${key}`);
  return val;
}

// v104: production-required env vars have NO dev fallback.
// Dev fallback only applies when NODE_ENV !== 'production'.
const isProduction = process.env.NODE_ENV === 'production';
const productionRequired = (key: string, fallback: string): string => {
  const value = process.env[key];
  if (value) return value;
  if (isProduction) throw new Error(`Missing env: ${key}`);
  return fallback;
};

export const config = {
  DATABASE_URL: process.env.DATABASE_URL || required('DATABASE_URL'),
  JWT_SECRET: productionRequired('JWT_SECRET', 'dev-secret-change-me'),
  JWT_REFRESH_SECRET: productionRequired('JWT_REFRESH_SECRET', 'dev-refresh-secret-change-me'),
  // v104: in production CORS_ORIGIN must be explicit (no wildcard with credentials)
  CORS_ORIGIN: productionRequired('CORS_ORIGIN', '*'),
  PORT: parseInt(process.env.PORT || '8080'),

  REDIS_URL: process.env.REDIS_URL || '',
  SENTRY_DSN: process.env.SENTRY_DSN || '',
  SLACK_WEBHOOK_URL: process.env.SLACK_WEBHOOK_URL || '',

  // 🔧 Pack 1.1: Увеличенные TTL для удобства пользователей
  // Access token = 7 дней (не выкидывает из 6-часового фильма)
  // Refresh token = 90 дней (редко просит пароль)
  ACCESS_TOKEN_TTL: process.env.ACCESS_TOKEN_TTL || '7d',
  REFRESH_TOKEN_TTL_DAYS: parseInt(process.env.REFRESH_TOKEN_TTL_DAYS || '90'),

  NODE_ENV: process.env.NODE_ENV || 'development',
  isProduction,
};
