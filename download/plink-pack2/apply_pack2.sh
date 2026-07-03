#!/bin/bash
# Pack 1.1 + Pack 2: Security + Auto-refresh iOS
set -e

echo "════════════════════════════════════════════════════════════"
echo "  Plink Pack 1.1 + Pack 2"
echo "  - Access token TTL: 7 дней (не выкидывает из фильма)"
echo "  - Refresh token TTL: 90 дней"
echo "  - Signin: 10/5min, Signup: 5/20min, Refresh: 60/1min"
echo "  - iOS: Auto-refresh + Keychain storage"
echo "════════════════════════════════════════════════════════════"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$HOME/Desktop/plink-backend"
IOS_DIR="$HOME/Desktop/plink"

# ── 1. Backend Pack 1.1 ──
if [ -d "$BACKEND_DIR" ]; then
    echo "🔧 Backend: обновляю TTL и rate limits..."
    
    if [ -f "$SCRIPT_DIR/backend/src/config/index.ts" ]; then
        cp "$SCRIPT_DIR/backend/src/config/index.ts" "$BACKEND_DIR/src/config/index.ts"
        cp "$SCRIPT_DIR/backend/src/routes/auth.ts"   "$BACKEND_DIR/src/routes/auth.ts"
        cp "$SCRIPT_DIR/backend/src/utils/tokens.ts"  "$BACKEND_DIR/src/utils/tokens.ts"
        
        cd "$BACKEND_DIR"
        git add -A
        git commit -m "Pack 1.1: увеличенные TTL (access 7d, refresh 90d) + правильные rate limits

- Access token: 15min → 7d (не выкидывает из 6-часового фильма)
- Refresh token: 30d → 90d (редко просит пароль)
- Signin: 5/min → 10/5min
- Signup: 3/hour → 5/20min  
- Refresh: 30/min → 60/min (каждый запуск приложения)
- TTL настраивается через env: ACCESS_TOKEN_TTL, REFRESH_TOKEN_TTL_DAYS" || echo "⚠️ nothing to commit"
        git push
        echo "✅ Backend Pack 1.1 запушен"
    fi
fi

# ── 2. iOS Pack 2 ──
if [ -d "$IOS_DIR" ]; then
    echo ""
    echo "🔧 iOS: обновляю AuthService с auto-refresh..."
    
    if [ -f "$SCRIPT_DIR/ios/Plink/Services/AuthService.swift" ]; then
        # Бэкап старого файла
        cp "$IOS_DIR/Plink/Services/AuthService.swift" "$IOS_DIR/Plink/Services/AuthService.swift.bak"
        
        cp "$SCRIPT_DIR/ios/Plink/Services/AuthService.swift" "$IOS_DIR/Plink/Services/AuthService.swift"
        
        cd "$IOS_DIR"
        git add -A
        git commit -m "Pack 2: iOS auto-refresh + Keychain storage

- AuthService переписан с Keychain для access + refresh tokens
- Auto-login при запуске приложения (читает refresh token)
- Auto-refresh: при истечении access token автоматически /auth/refresh
- Mutex на одновременные refresh запросы
- Logout отзывает все refresh tokens на бэкенде
- AuthError с понятными сообщениями для пользователя
- Старый файл сохранён как AuthService.swift.bak" || echo "⚠️ nothing to commit"
        git push
        echo "✅ iOS Pack 2 запушен"
    fi
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ Готово!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "После деплоя бэкенда (1-2 мин) проверьте:"
echo "  curl -X POST https://plink-backend-production-ef31.up.railway.app/api/auth/signin \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"email\":\"test@test.com\",\"password\":\"123456\"}'"
echo ""
echo "Должен вернуть: token + refreshToken + accessExpiresAt (через 7 дней)"
echo ""
echo "⚠️ Если бэкенд упал с 'table RefreshToken does not exist' —"
echo "  примените миграцию БД:"
echo "  DATABASE_URL='postgresql://postgres:hnKtyITKVNXhwEYbDYrVvbjReBfaFlqp@reseau.proxy.rlwy.net:51724/railway' npx prisma db push"
echo ""
echo "📱 В Xcode после открытия проекта:"
echo "  1. Соберите (Cmd+B) — должны быть ошибки если AuthService"
echo "     использует другой APIClient singleton"
echo "  2. Если нужно — поправьте APIClient.shared или замените на ваш паттерн"
echo "  3. Удалите дубликат KeychainHelper из YandexAuthService.swift если есть"
echo "  4. Cmd+R — должно работать с авто-логином"
