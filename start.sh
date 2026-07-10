#!/bin/sh
# start.sh — Railway/Docker startup script with explicit step logging.
# v104: extraction moved to iOS — no yt-dlp. Production uses prisma migrate deploy.
set -e

echo "==== Step 1/3: prisma generate ===="
npx prisma generate
echo "==== Step 1/3 done (exit $?) ===="

echo "==== Step 2/3: prisma migrate deploy ===="
# Production-safe: applies pending migrations only. Never mutates schema destructively.
# < /dev/null: hard-block stdin so prisma can NEVER wait for input.
npx prisma migrate deploy < /dev/null
echo "==== Step 2/3 done (exit $?) ===="

echo "==== Step 3/3: starting Plink backend (tsx src/index.ts) ===="
exec npx tsx src/index.ts
