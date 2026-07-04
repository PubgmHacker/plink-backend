#!/bin/bash
# ════════════════════════════════════════════════════════════════════
# Plink Pack 8 — ВОССТАНОВЛЕНИЕ + ОЧИСТКА + ДОРАБОТКА ДИЗАЙНА
# ════════════════════════════════════════════════════════════════════
#
# Что делает Pack 8:
# 1. ВОССТАНАВЛИВАЕТ оригинальные view (HomeView, ProfileView, RoomView, SettingsView,
#    FriendsView, MainTabView, PaywallView) из backup-ветки
# 2. УДАЛЯЕТ 2FA (TwoFactorSetupView.swift + backend twofa.ts)
# 3. УДАЛЯЕТ финансовую Referral систему (ReferralView.swift + backend referral.ts)
# 4. УДАЛЯЕТ stub RoomsViewFixed.swift
# 5. УЛУЧШАЕТ цветовую палитру: cyan/teal/emerald + тёплые акценты (coral/amber/rose)
# 6. Сохраняет AvatarView с bioNeonRing (Premium/Admin)
# 7. Сохраняет KeychainHelper с миграцией
#
# Результат: красивый биолюминесцентный дизайн + чистый код без overengineering
# ════════════════════════════════════════════════════════════════════

set -e

echo "═══════════════════════════════════════════════════════════════════"
echo "  Plink Pack 8 — Восстановление + Очистка + Дизайн"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "  Что будет сделано:"
echo "  1. Восстановлены оригинальные view (HomeView, ProfileView, RoomView, ...)"
echo "  2. Удалён 2FA (overengineering)"
echo "  3. Удалена Referral system (не вписывается в концепцию)"
echo "  4. Удалён stub RoomsViewFixed"
echo "  5. Улучшена палитра: cyan/teal/emerald + coral/amber/rose"
echo "  6. Сохранены AvatarView и KeychainHelper"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$HOME/Desktop/plink"
BACKEND_DIR="$HOME/Desktop/plink-backend"

# ────────────────────────────────────────────────────────────────────
# ПРОВЕРКА ПАПОК
# ────────────────────────────────────────────────────────────────────

if [ ! -d "$IOS_DIR" ]; then
    echo "❌ iOS проект не найден: $IOS_DIR"
    exit 1
fi

echo "✅ iOS проект: $IOS_DIR"
echo ""

# ────────────────────────────────────────────────────────────────────
# ШАГ 1: ВОССТАНОВЛЕНИЕ ОРИГИНАЛЬНЫХ VIEW
# ────────────────────────────────────────────────────────────────────

echo "🔄 Шаг 1: Восстановление оригинальных view..."

# Backup текущих (сломанных) версий
mkdir -p "$IOS_DIR/Plink/_pack8_backup"
for f in Color+Theme.swift Views/Components/MainTabView.swift Views/Home/HomeView.swift \
         Views/Profile/ProfileView.swift Views/Room/RoomView.swift \
         Views/Settings/SettingsView.swift Views/Friends/FriendsView.swift \
         Views/Premium/PaywallView.swift Views/Components/AvatarView.swift \
         Utilities/KeychainHelper.swift Views/Components/AnimatedGradientBackground.swift \
         Views/Components/BioluminescentBackground.swift; do
    if [ -f "$IOS_DIR/Plink/$f" ]; then
        cp "$IOS_DIR/Plink/$f" "$IOS_DIR/Plink/_pack8_backup/$(basename $f).broken.bak"
    fi
done

# Копируем оригиналы из pack8
cp "$SCRIPT_DIR/ios/Plink/Extensions/Color+Theme.swift" \
   "$IOS_DIR/Plink/Extensions/Color+Theme.swift"
cp "$SCRIPT_DIR/ios/Plink/Views/Components/MainTabView.swift" \
   "$IOS_DIR/Plink/Views/Components/MainTabView.swift"
cp "$SCRIPT_DIR/ios/Plink/Views/Home/HomeView.swift" \
   "$IOS_DIR/Plink/Views/Home/HomeView.swift"
cp "$SCRIPT_DIR/ios/Plink/Views/Profile/ProfileView.swift" \
   "$IOS_DIR/Plink/Views/Profile/ProfileView.swift"
cp "$SCRIPT_DIR/ios/Plink/Views/Room/RoomView.swift" \
   "$IOS_DIR/Plink/Views/Room/RoomView.swift"
cp "$SCRIPT_DIR/ios/Plink/Views/Settings/SettingsView.swift" \
   "$IOS_DIR/Plink/Views/Settings/SettingsView.swift"
cp "$SCRIPT_DIR/ios/Plink/Views/Friends/FriendsView.swift" \
   "$IOS_DIR/Plink/Views/Friends/FriendsView.swift"
cp "$SCRIPT_DIR/ios/Plink/Views/Premium/PaywallView.swift" \
   "$IOS_DIR/Plink/Views/Premium/PaywallView.swift"
cp "$SCRIPT_DIR/ios/Plink/Views/Components/AvatarView.swift" \
   "$IOS_DIR/Plink/Views/Components/AvatarView.swift"
cp "$SCRIPT_DIR/ios/Plink/Utilities/KeychainHelper.swift" \
   "$IOS_DIR/Plink/Utilities/KeychainHelper.swift"
cp "$SCRIPT_DIR/ios/Plink/Views/Components/AnimatedGradientBackground.swift" \
   "$IOS_DIR/Plink/Views/Components/AnimatedGradientBackground.swift"
cp "$SCRIPT_DIR/ios/Plink/Views/Components/BioluminescentBackground.swift" \
   "$IOS_DIR/Plink/Views/Components/BioluminescentBackground.swift"

echo "   ✅ Восстановлено 12 файлов"
echo ""

# ────────────────────────────────────────────────────────────────────
# ШАГ 2: УДАЛЕНИЕ 2FA И REFERRAL
# ────────────────────────────────────────────────────────────────────

echo "🗑️  Шаг 2: Удаление 2FA и Referral системы..."

# iOS: удалить 2FA и Referral view
rm -f "$IOS_DIR/Plink/Views/Components/TwoFactorSetupView.swift"
rm -f "$IOS_DIR/Plink/Views/Components/ReferralView.swift"
rm -f "$IOS_DIR/Plink/Views/Home/RoomsViewFixed.swift"

# Удалить .bak файлы от предыдущих паков
find "$IOS_DIR/Plink" -name "*.swift.bak" -delete 2>/dev/null || true

# Backend: удалить 2FA и Referral routes
if [ -d "$BACKEND_DIR" ]; then
    rm -f "$BACKEND_DIR/src/routes/twofa.ts"
    rm -f "$BACKEND_DIR/src/routes/referral.ts"
    
    # Убрать регистрацию из index.ts
    if [ -f "$BACKEND_DIR/src/index.ts" ]; then
        sed -i.bak '/import twofaRoutes/d' "$BACKEND_DIR/src/index.ts"
        sed -i.bak '/import referralRoutes/d' "$BACKEND_DIR/src/index.ts"
        sed -i.bak "/register(twofaRoutes/d" "$BACKEND_DIR/src/index.ts"
        sed -i.bak "/register(referralRoutes/d" "$BACKEND_DIR/src/index.ts"
        rm -f "$BACKEND_DIR/src/index.ts.bak"
    fi
fi

echo "   ✅ Удалено:"
echo "      - TwoFactorSetupView.swift"
echo "      - ReferralView.swift"
echo "      - RoomsViewFixed.swift (stub)"
echo "      - backend twofa.ts + referral.ts"
echo "      - *.swift.bak файлы"
echo ""

# ────────────────────────────────────────────────────────────────────
# ШАГ 3: ГИТ КОММИТ
# ────────────────────────────────────────────────────────────────────

echo "📤 Шаг 3: Git commit и push..."

cd "$IOS_DIR"
git add -A
git commit -m "Pack 8: Восстановление оригиналов + удаление 2FA/Referral + улучшенная палитра

Восстановлены оригинальные view из backup-ветки:
- HomeView: 'Сейчас в эфире' + 'Рекомендации для тебя' + floating CTA
- ProfileView: реальный профиль с аватаром, статистикой, историей
- RoomView: Ambilight фон + видео + чат (portrait/landscape)
- SettingsView: Apple ID-стиль, биолюминесцентный фон
- FriendsView: список друзей + запросы + поиск
- MainTabView: 5 вкладок (Главная/Комнаты/ИИ/Друзья/Настройки)
- PaywallView: 3 тарифа (1мес/3мес/12мес) с cyan glow
- AvatarView: кольцо только для Premium (bioNeonRing) и Admin
- KeychainHelper: с миграцией legacy токенов
- AnimatedGradientBackground + BioluminescentBackground

Удалено (overengineering):
- TwoFactorSetupView.swift — 2FA не нужна для видео-приложения
- ReferralView.swift — финансовая рефералка не вписывается
- RoomsViewFixed.swift — stub конфликтовал с оригиналом
- backend twofa.ts + referral.ts

Улучшена цветовая палитра:
- Основной спектр: cyan/teal/emerald (биолюминесценция)
- Тёплые акценты: coral (#FF6B6B), amber (#FFB454), rose (#FF8FAB)
- Новые градиенты: reactionGradient, friendsGradient, premiumGradient
- sunsetGradient (coral→emerald), abyssGradient (cyan→rose)
- Фон: обсидиан #0A0D14 (сквозной)
- Стекло: полупрозрачный белый 3-5%" || echo "⚠️ nothing to commit"

git push

# Backend commit
if [ -d "$BACKEND_DIR" ]; then
    cd "$BACKEND_DIR"
    git add -A
    git commit -m "Pack 8: Удаление 2FA и Referral routes (overengineering cleanup)

Удалено:
- src/routes/twofa.ts — 2FA не нужна для видео-приложения
- src/routes/referral.ts — финансовая рефералка не вписывается
- Регистрация в index.ts убрана

Оставлено (полезное из паков 1-5):
- JWT refresh tokens (15min access + 90d refresh)
- Redis cache для /api/rooms
- AuditLog (compliance)
- Rate limiting (per-endpoint)
- GDPR endpoints (App Store requirement)
- StoreKit 2 receipt validation
- yt-dlp stream extraction
- AI Assistant (OpenRouter)
- WebSocket presence + typing
- Metrics (/metrics)
- Sentry integration" || echo "⚠️ nothing to commit"
    git push
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  ✅ Pack 8 применён!"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "📋 Что делать дальше:"
echo ""
echo "1. В Xcode:"
echo "   - Удалите TwoFactorSetupView.swift из навигатора (если остался)"
echo "   - Удалите ReferralView.swift из навигатора (если остался)"
echo "   - Удалите RoomsViewFixed.swift из навигатора (если остался)"
echo "   - Cmd+B → собрать (должно быть без ошибок)"
echo "   - Cmd+R → запустить"
echo ""
echo "2. Проверьте в приложении:"
echo "   ✅ Главная: 'Сейчас в эфире' + 'Рекомендации для тебя'"
echo "   ✅ Floating CTA 'Создать комнату' (сворачивается через 8 сек)"
echo "   ✅ Профиль: реальный аватар + статистика + история"
echo "   ✅ Комната: Ambilight + видео + чат"
echo "   ✅ Настройки: Apple ID-стиль, 5 разделов"
echo "   ✅ Премиум: 3 тарифа (1мес/3мес/12мес)"
echo "   ✅ Дизайн: cyan/teal/emerald + тёплые акценты"
echo "   ❌ 2FA: удалено"
echo "   ❌ Рефералка: удалена"
echo ""
echo "3. Цветовая палитра:"
echo "   Фон:     #0A0D14 (обсидиан)"
echo "   Основной: #2DE2E6 (cyan) + #0EB5C9 (teal) + #26D9A4 (emerald)"
echo "   Тёплый:   #FF6B6B (coral) + #FFB454 (amber) + #FF8FAB (rose)"
echo "   Стекло:   белый 4% + bioNeonRing"
