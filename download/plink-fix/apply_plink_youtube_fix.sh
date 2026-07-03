#!/bin/bash
# Plink Backend + iOS — Apply YouTube Search Fix
# Запускать на маке: bash apply_plink_youtube_fix.sh
set -e

echo "════════════════════════════════════════════════════════════"
echo "  Plink YouTube Integration Fix"
echo "════════════════════════════════════════════════════════════"

# ── 0. Найти папки plink-backend и plink-ios на десктопе ──
BACKEND_DIR="$HOME/Desktop/plink-backend"
IOS_DIR="$HOME/Desktop/plink-ios"

if [ ! -d "$BACKEND_DIR" ]; then
    echo "❌ Не найдена папка $BACKEND_DIR"
    echo "   Укажите путь: read -p 'Backend dir: ' BACKEND_DIR"
    exit 1
fi
if [ ! -d "$IOS_DIR" ]; then
    echo "❌ Не найдена папка $IOS_DIR"
    echo "   Укажите путь: read -p 'iOS dir: ' IOS_DIR"
    exit 1
fi

echo "✅ Backend: $BACKEND_DIR"
echo "✅ iOS:     $IOS_DIR"
echo ""

# ── 1. ССОРИ файлы лежат в той же папке что и скрипт ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_SRC="$SCRIPT_DIR/media.ts"
INDEX_SRC="$SCRIPT_DIR/index.ts"

if [ ! -f "$MEDIA_SRC" ]; then
    echo "❌ Не найден $MEDIA_SRC — распакуйте архив рядом со скриптом"
    exit 1
fi

# ── 2. Применить изменения к бэкенду ──
echo "🔧 Backend: добавляю src/routes/media.ts"
cp "$MEDIA_SRC" "$BACKEND_DIR/src/routes/media.ts"

echo "🔧 Backend: обновляю src/index.ts"
cp "$INDEX_SRC" "$BACKEND_DIR/src/index.ts"

# ── 3. Поправить YouTubeSearchService.swift на iOS ──
echo "🔧 iOS: правлю URL в YouTubeSearchService.swift"
sed -i '' 's|https://raveclone.app/api|https://plink-backend-production-ef31.up.railway.app/api|g' \
    "$IOS_DIR/Plink/Services/YouTubeSearchService.swift"

# ── 4. Закоммитить и запушить бэкенд ──
echo ""
echo "📤 Push backend..."
cd "$BACKEND_DIR"
git add src/routes/media.ts src/index.ts
git commit -m "Add YouTube search and extract endpoints" || echo "⚠️ nothing to commit (уже было)"
git push

# ── 5. Закоммитить и запушить iOS ──
echo ""
echo "📤 Push iOS..."
cd "$IOS_DIR"
git add Plink/Services/YouTubeSearchService.swift
git commit -m "Switch YouTubeSearchService to Railway backend" || echo "⚠️ nothing to commit"
git push

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ Готово!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Теперь добавьте YOUTUBE_API_KEY в Railway:"
echo "  Railway → plink-backend → Variables → New Variable"
echo "  Name:  YOUTUBE_API_KEY"
echo "  Value: AIzaSyBGzu1DQaoDc-5yDk284Gg9bu1s4UmXgOk"
echo ""
echo "После деплоя проверьте поиск:"
echo "  TOKEN=\$(curl -s -X POST https://plink-backend-production-ef31.up.railway.app/api/auth/signin \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"email\":\"test@test.com\",\"password\":\"123456\"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)[\"token\"])')"
echo "  curl 'https://plink-backend-production-ef31.up.railway.app/api/media/search?q=lofi&limit=5' \\"
echo "    -H \"Authorization: Bearer \$TOKEN\""
