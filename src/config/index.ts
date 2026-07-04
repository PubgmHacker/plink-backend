function required(key: string): string {
  const val = process.env[key];
  if (!val) throw new Error(`Missing env: ${key}`);
  return val;
}

export const config = {
  DATABASE_URL: process.env.DATABASE_URL || required('DATABASE_URL'),
  JWT_SECRET: process.env.JWT_SECRET || 'dev-secret-change-me',
  CORS_ORIGIN: process.env.CORS_ORIGIN || '*',
  PORT: parseInt(process.env.PORT || '8080'),
};
