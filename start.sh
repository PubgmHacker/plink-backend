#!/bin/sh
# start.sh — Railway/Docker startup script (v2 stabilize/protocol-v2)
#
# v2 changes per runbook §2:
#   - Use prisma migrate deploy (NOT db push) — proper migration history
#   - Build TypeScript to dist/ in Docker builder stage (NOT at runtime)
#   - yt-dlp no longer installed by default — legacy stream relay is gated
#     behind APP_STORE_COMPLIANT=false && ENABLE_LEGACY_STREAM_RELAY=true
#
# AUDIT Block 3.3: APNs key written from env var at startup.
set -e

echo "==== Step 1/3: prisma generate ===="
npx prisma generate
echo "==== Step 1/3 done ===="

echo "==== Step 2/3: prisma migrate deploy + APNs key ===="
# Production-safe: applies pending migrations only, does NOT create new ones.
npx prisma migrate deploy < /dev/null

# Write APNs .p8 key from env var to file (Railway stores it as env, not as file)
if [ -n "$APNS_KEY_CONTENT" ]; then
  echo "Writing APNs key file from APNS_KEY_CONTENT env var..."
  echo "$APNS_KEY_CONTENT" > /app/AuthKey.p8
  export APNS_KEY_PATH="/app/AuthKey.p8"
  echo "APNs key written to $APNS_KEY_PATH"
else
  echo "WARNING: APNS_KEY_CONTENT not set — push notifications will not work."
fi
echo "==== Step 2/3 done ===="

echo "==== Step 3/3: start server ===="
export NODE_ENV="${NODE_ENV:-production}"
exec node dist/server.js
