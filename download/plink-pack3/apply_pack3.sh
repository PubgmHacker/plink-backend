#!/bin/bash
# Plink Pack 3: Media + Monetization
# - yt-dlp stream extraction (YouTube, VK, RuTube, etc.)
# - StoreKit 2 Premium (monthly/yearly/lifetime)
# - Receipt validation на бэкенде
# - Netflix WebView с JS injection для sync
set -e

echo "════════════════════════════════════════════════════════════"
echo "  Plink Pack 3: Media + Monetization"
echo "  - yt-dlp stream extraction (YouTube, VK, RuTube, Vimeo)"
echo "  - StoreKit 2 (monthly/yearly/lifetime premium)"
echo "  - Server-side receipt validation"
echo "  - Netflix WebView с JS injection"
echo "════════════════════════════════════════════════════════════"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$HOME/Desktop/plink-backend"
IOS_DIR="$HOME/Desktop/plink"

# ── 1. Backend Pack 3 ──
if [ -d "$BACKEND_DIR" ]; then
    echo ""
    echo "🔧 Backend: добавляю yt-dlp + billing routes..."
    
    if [ -f "$SCRIPT_DIR/backend/src/services/streamExtractor.ts" ]; then
        # Создать папку services если нет
        mkdir -p "$BACKEND_DIR/src/services"
        
        cp "$SCRIPT_DIR/backend/src/services/streamExtractor.ts" "$BACKEND_DIR/src/services/streamExtractor.ts"
        cp "$SCRIPT_DIR/backend/src/routes/media.ts"    "$BACKEND_DIR/src/routes/media.ts"
        cp "$SCRIPT_DIR/backend/src/routes/billing.ts"  "$BACKEND_DIR/src/routes/billing.ts"
        cp "$SCRIPT_DIR/backend/src/index.ts"           "$BACKEND_DIR/src/index.ts"
        cp "$SCRIPT_DIR/backend/Dockerfile"             "$BACKEND_DIR/Dockerfile"
        
        cd "$BACKEND_DIR"
        git add -A
        git commit -m "Pack 3: Media extraction + StoreKit billing

Backend:
- yt-dlp stream extraction (YouTube/VK/RuTube/Vimeo/Dailymotion)
- /api/media/extract?id=VIDEO_ID — прямой stream URL
- /api/media/extract-url (POST) — извлечение по любому URL
- /api/media/metadata — только метаданные
- Redis cache для extraction (1 hour TTL)
- /api/billing/verify — Apple receipt validation
- /api/billing/status — статус premium
- /api/billing/cancel — отмена подписки
- Dockerfile: добавлен yt-dlp + ffmpeg
- Index: регистрация billingRoutes, version 1.3.0" || echo "⚠️ nothing to commit"
        git push
        echo "✅ Backend Pack 3 запушен"
    fi
fi

# ── 2. iOS Pack 3 ──
if [ -d "$IOS_DIR" ]; then
    echo ""
    echo "🔧 iOS: добавляю StoreManager + PaywallView + NetflixPlayerView..."
    
    if [ -f "$SCRIPT_DIR/ios/Plink/Services/StoreManager.swift" ]; then
        mkdir -p "$IOS_DIR/Plink/Views/Premium"
        
        cp "$SCRIPT_DIR/ios/Plink/Services/StoreManager.swift"      "$IOS_DIR/Plink/Services/StoreManager.swift"
        cp "$SCRIPT_DIR/ios/Plink/Services/NetflixPlayerView.swift" "$IOS_DIR/Plink/Services/NetflixPlayerView.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Premium/PaywallView.swift"  "$IOS_DIR/Plink/Views/Premium/PaywallView.swift"
        
        cd "$IOS_DIR"
        git add -A
        git commit -m "Pack 3: iOS StoreKit 2 + Netflix WebView injection

iOS:
- StoreManager.swift — StoreKit 2 singleton (load products, purchase, restore)
- PaywallView.swift — красивый paywall с 3 планами (monthly/yearly/lifetime)
- NetflixPlayerView.swift — WebView с JS injection для Netflix/Disney+/HBO sync
- JS bridge: читает play/pause/seek состояние плеера каждые 500ms
- Поддержка как Netflix API, так и fallback на <video> element" || echo "⚠️ nothing to commit"
        git push
        echo "✅ iOS Pack 3 запушен"
    fi
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ Pack 3 запушен!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Что нужно сделать в Railway (Variables → plink-backend):"
echo ""
echo "  1. APP_STORE_SHARED_SECRET — для StoreKit receipt validation"
echo "     Получить: App Store Connect → App → App Information →"
echo "     App-Specific Shared Secret → Manage → Generate"
echo ""
echo "  2. Railway задеплоит с новым Dockerfile (yt-dlp + ffmpeg)"
echo "     Билд займёт ~3-4 минуты (дольше обычного)"
echo ""
echo "После деплоя проверьте:"
echo "  curl 'https://plink-backend-production-ef31.up.railway.app/api/media/extract?id=sF80I-TQiW0' \\"
echo "    -H 'Authorization: Bearer TOKEN'"
echo "  Должен вернуть streamURL (прямой URL для AVPlayer)"
echo ""
echo "Тест billing status:"
echo "  curl https://plink-backend-production-ef31.up.railway.app/api/billing/status \\"
echo "    -H 'Authorization: Bearer TOKEN'"
echo "  Должен вернуть: { \"isPremium\": false, \"premiumUntil\": null }"
echo ""
echo "📱 В Xcode:"
echo "  1. Добавить в Xcode project: Plink/Services/StoreManager.swift"
echo "     Plink/Services/NetflixPlayerView.swift"
echo "     Plink/Views/Premium/PaywallView.swift"
echo "  2. App Store Connect → создайте 3 In-App Purchases:"
echo "     - plink.premium.monthly (\$1.99)"
echo "     - plink.premium.yearly (\$19.90)"
echo "     - plink.premium.lifetime (\$49.90)"
echo "  3. В RaveCloneApp.swift: @StateObject private var store = StoreManager.shared"
echo "  4. Добавить кнопку Premium в Profile или Settings"
echo "     Button('Plink Premium') { showPaywall = true }"
echo "     .sheet(isPresented: \$showPaywall) { PaywallView() }"
echo ""
echo "⚠️ Важно: Netflix WebView будет работать только если юзер"
echo "  сам залогинится в Netflix через WebView. DRM обрабатывает"
echo "  сам Netflix."
