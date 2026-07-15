#!/bin/sh
# start.sh — Railway/Docker startup script (v2 stabilize/protocol-v2)
#
# v2 changes per runbook §2:
#   - Use prisma migrate deploy (NOT db push) — proper migration history
#   - Build TypeScript to dist/ then run compiled JS (no tsx in production)
#   - yt-dlp no longer installed by default — legacy stream relay is gated
#     behind APP_STORE_COMPLIANT=false && ENABLE_LEGACY_STREAM_RELAY=true
set -e

echo "==== Step 1/3: prisma generate ===="
npx prisma generate
echo "==== Step 1/3 done ===="

# Ensure uploads dir for avatars (persistent volume recommended on Railway)
mkdir -p /app/uploads/avatars
echo "Uploads dir ready"

echo "==== Step 2/3: prisma migrate deploy ===="
# Production-safe: applies pending migrations only, does NOT create new ones.
# If migrations don't exist yet, you MUST run 'prisma migrate dev' locally,
# review the generated SQL, commit it, then deploy.
npx prisma migrate deploy < /dev/null
echo "==== Step 2/3 done ===="

echo "==== Step 3/3: build + start (node dist/server.js) ===="
npm run build
export NODE_ENV="${NODE_ENV:-production}"
exec node dist/server.js
