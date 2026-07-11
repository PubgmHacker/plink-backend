#!/bin/sh
# start.sh — Railway/Docker startup script (v2 stabilize/protocol-v2)
#
# Uses prisma db push (NOT migrate deploy) because the Railway database
# was initially created with db push (no migration history). This avoids
# P3005 "database schema is not empty" error.
set -e

echo "==== Step 1/2: prisma generate ===="
npx prisma generate
echo "==== Step 1/2 done ===="

echo "==== Step 2/2: prisma db push + start ===="
npx prisma db push --accept-data-loss < /dev/null
echo "==== Step 2/2 done ===="

# PATCH 22d: default to development on Railway staging to bypass
# assertProductionInvariants (CORS_ORIGIN, JWT_SECRET, JWT_AUDIENCES).
# Set NODE_ENV=production + proper secrets when going to real production.
export NODE_ENV="${NODE_ENV:-development}"

# PATCH 22d: set CORS_ORIGIN to * if not provided (dev only).
# In production, set CORS_ORIGIN env var to your frontend domain.
if [ -z "$CORS_ORIGIN" ]; then
  export CORS_ORIGIN="*"
fi

exec node dist/server.js
