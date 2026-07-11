#!/bin/sh
# start.sh — Railway/Docker startup script (v2 stabilize/protocol-v2)
#
# v2 changes per runbook §2:
#   - Use prisma migrate deploy (NOT db push) — proper migration history
#   - Build TypeScript to dist/ in Docker builder stage (NOT at runtime)
#   - yt-dlp no longer installed by default — legacy stream relay is gated
#     behind APP_STORE_COMPLIANT=false && ENABLE_LEGACY_STREAM_RELAY=true
set -e

echo "==== Step 1/2: prisma generate ===="
npx prisma generate
echo "==== Step 1/2 done ===="

echo "==== Step 2/2: prisma migrate deploy + start ===="
# Production-safe: applies pending migrations only, does NOT create new ones.
# If migrations don't exist yet, you MUST run 'prisma migrate dev' locally,
# review the generated SQL, commit it, then deploy.
npx prisma migrate deploy < /dev/null
echo "==== Step 2/2 done ===="

export NODE_ENV="${NODE_ENV:-production}"
exec node dist/server.js
