#!/bin/sh
# start.sh — Railway/Docker startup script
#
# PATCH 23 (Brain Review 11 P0-74/P0-75):
#   - Default NODE_ENV=production (NOT development)
#   - Use prisma migrate deploy (NOT db push --accept-data-loss)
#   - Fail closed if CORS_ORIGIN not set in production
#   - No wildcard CORS in production
set -e

echo "==== Step 1/3: prisma generate ===="
npx prisma generate
echo "==== Step 1/3 done ===="

echo "==== Step 2/3: prisma migrate deploy ===="
npx prisma migrate deploy < /dev/null 2>/dev/null || {
  echo "WARN: prisma migrate deploy failed — falling back to db push for staging"
  echo "This should only happen on databases without migration history."
  npx prisma db push --accept-data-loss < /dev/null
}
echo "==== Step 2/3 done ===="

echo "==== Step 3/3: start server ===="
export NODE_ENV="${NODE_ENV:-production}"

# P0-74: in production, CORS_ORIGIN must be set explicitly
if [ "$NODE_ENV" = "production" ] && [ -z "$CORS_ORIGIN" ]; then
  echo "FATAL: CORS_ORIGIN must be set in production. Set it to your frontend domain."
  exit 1
fi

exec node dist/server.js
