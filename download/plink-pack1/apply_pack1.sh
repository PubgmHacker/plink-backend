#!/bin/bash
# Plink Backend Pack 1: Security + Backend Improvements
# Запускать на маке в папке с распакованным архивом: bash apply_pack1.sh
set -e

echo "════════════════════════════════════════════════════════════"
echo "  Plink Pack 1: Security + Backend"
echo "  - JWT refresh tokens (15min access + 30d refresh)"
echo "  - Granular rate limits (per-endpoint)"
echo "  - AuditLog (логирование действий)"
echo "  - Redis cache для /api/rooms"
echo "  - Extended /health (DB, Redis, memory)"
echo "  - Sentry integration"
echo "  - Slack alerting"
echo "  - Graceful shutdown"
echo "════════════════════════════════════════════════════════════"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$HOME/Desktop/plink-backend"

if [ ! -d "$BACKEND_DIR" ]; then
    echo "❌ Не найдена папка $BACKEND_DIR"
    echo "   Укажите путь: export BACKEND_DIR=/path/to/plink-backend"
    exit 1
fi

if [ ! -d "$SCRIPT_DIR/backend/src" ]; then
    echo "❌ Архив распакован неправильно — нет папки backend/src"
    echo "   Распакуйте plink-pack1.zip в отдельную папку и запустите скрипт оттуда"
    exit 1
fi

echo "✅ Backend dir: $BACKEND_DIR"
echo "✅ Source files: $SCRIPT_DIR/backend"
echo ""

# ── 1. Копировать файлы ──
echo "🔧 1/6. Копирую prisma/schema.prisma (с RefreshToken + AuditLog)"
cp "$SCRIPT_DIR/backend/../prisma/schema.prisma" "$BACKEND_DIR/prisma/schema.prisma"

echo "🔧 2/6. Копирую backend/src/config/*"
cp "$SCRIPT_DIR/backend/src/config/index.ts" "$BACKEND_DIR/src/config/index.ts"
cp "$SCRIPT_DIR/backend/src/config/redis.ts" "$BACKEND_DIR/src/config/redis.ts"

echo "🔧 3/6. Копирую backend/src/utils/*"
mkdir -p "$BACKEND_DIR/src/utils"
cp "$SCRIPT_DIR/backend/src/utils/audit.ts"     "$BACKEND_DIR/src/utils/audit.ts"
cp "$SCRIPT_DIR/backend/src/utils/alerting.ts"  "$BACKEND_DIR/src/utils/alerting.ts"
cp "$SCRIPT_DIR/backend/src/utils/tokens.ts"    "$BACKEND_DIR/src/utils/tokens.ts"

echo "🔧 4/6. Копирую backend/src/middleware/auth.ts"
cp "$SCRIPT_DIR/backend/src/middleware/auth.ts" "$BACKEND_DIR/src/middleware/auth.ts"

echo "🔧 5/6. Копирую backend/src/routes/*"
cp "$SCRIPT_DIR/backend/src/routes/auth.ts"  "$BACKEND_DIR/src/routes/auth.ts"
cp "$SCRIPT_DIR/backend/src/routes/rooms.ts" "$BACKEND_DIR/src/routes/rooms.ts"

echo "🔧 6/6. Копирую backend/src/index.ts и package.json"
cp "$SCRIPT_DIR/backend/src/index.ts"   "$BACKEND_DIR/src/index.ts"
cp "$SCRIPT_DIR/backend/package.json"   "$BACKEND_DIR/package.json"

# ── 2. Установить новые зависимости ──
echo ""
echo "📦 Устанавливаю новые зависимости (ioredis, @sentry/node)..."
cd "$BACKEND_DIR"
npm install --omit=dev

# ── 3. Закоммитить и запушить ──
echo ""
echo "📤 Коммичу и пушу на GitHub..."
git add -A
git commit -m "Pack 1: Security + Backend improvements

- JWT refresh tokens (15min access + 30d refresh with rotation)
- Granular rate limits (per-endpoint: signin 5/min, signup 3/hour, etc.)
- AuditLog table + helper (logAudit) for all sensitive actions
- RefreshToken table with rotation on each refresh
- Redis cache for /api/rooms (30s TTL, graceful fallback)
- Extended /health endpoint (DB, Redis, memory, uptime)
- Sentry integration (if SENTRY_DSN env is set)
- Slack/Telegram alerting (if SLACK_WEBHOOK_URL env is set)
- Graceful shutdown (SIGTERM/SIGINT handlers)
- Uncaught exception + unhandled rejection handlers
- Structured logging with redacted auth headers" || echo "⚠️ nothing to commit"

git push

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ Pack 1 запушен на GitHub!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Что нужно сделать в Railway (Variables → plink-backend):"
echo ""
echo "  1. Добавить Redis (New → Database → Redis)"
echo "     Скопировать REDIS_URL из Connect → Public URL"
echo ""
echo "  2. Опционально — Sentry (https://sentry.io → New Project → Node.js):"
echo "     SENTRY_DSN = https://...@sentry.io/..."
echo ""
echo "  3. Опционально — Slack alerts:"
echo "     SLACK_WEBHOOK_URL = https://hooks.slack.com/services/..."
echo ""
echo "  4. После добавления переменных Railway передеплоит сам."
echo ""
echo "  5. Применить миграцию БД (создать новые таблицы RefreshToken, AuditLog):"
echo "     DATABASE_URL='postgresql://postgres:hnKtyITKVNXhwEYbDYrVvbjReBfaFlqp@reseau.proxy.rlwy.net:51724/railway' npx prisma db push"
echo ""
echo "  6. Проверить health:"
echo "     curl https://plink-backend-production-ef31.up.railway.app/health"
echo "     Должно вернуть JSON с services.database: 'up' и services.redis: 'up'"
echo ""
echo "  7. Тест refresh токенов:"
echo "     TOKEN=\$(curl -s -X POST https://plink-backend-production-ef31.up.railway.app/api/auth/signin \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"email\":\"test@test.com\",\"password\":\"123456\"}' | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d[\"refreshToken\"])')"
echo "     curl -X POST https://plink-backend-production-ef31.up.railway.app/api/auth/refresh \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d \"{\\\"refreshToken\\\":\$TOKEN}\""
