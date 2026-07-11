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
# db push applies schema changes directly, skipping migration history.
# Accept destructive changes in dev/staging; in production, review
# schema.prisma diff before deploying.
npx prisma db push --accept-data-loss < /dev/null
echo "==== Step 2/2 done ===="

export NODE_ENV="${NODE_ENV:-production}"
exec node dist/server.js
