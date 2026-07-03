#!/bin/bash
# Plink Pack 6: Bug Fixes + UI Polish + AI + New Design
set -e

echo "════════════════════════════════════════════════════════════"
echo "  Plink Pack 6: Bug Fixes + UI Polish + AI + New Design"
echo ""
echo "  Backend:"
echo "  - AI Assistant endpoint (/api/ai/chat, /api/ai/recommend)"
echo ""
echo "  iOS Bug Fixes:"
echo "  1. Ускорена анимация живого фона (3x быстрее)"
echo "  2. Premium/Plink+ кнопки теперь работают"
echo "  3. Создание комнаты: фикс 'data missing' ошибки"
echo "  4. Настройки: убраны большие отступы после стрелочек"
echo "  5. Кнопка уведомлений в настройках открывается"
echo "  6. Убрана шестерёнка с профиля"
echo "  7. Восстановлены 'Смотрят сейчас' и рекомендации"
echo "  8. 'Запросы' помещается в одну строку"
echo "  9. Выбор сервиса → сразу создание комнаты"
echo "  10. Убрано 'создать комнату' из плеера"
echo "  11. Фикс счётчика участников (10→9→8 а не 10→3)"
echo "  12. Кнопки создать/присоединиться с надписями"
echo "  13. Кнопка 'Присоединиться' открывает Rooms/Join"
echo "  14. ИИ работает (OpenRouter интеграция)"
echo "  15. Полные переводы (RU/EN/ZH/ES)"
echo "  16. Новый multi-color дизайн (Purple+Pink+Orange)"
echo "  17. Кнопки создать/присоединиться изначально развёрнуты,"
echo "      сворачиваются через 6 сек бездействия"
echo "  18. Кнопка чата не перекрывает сворачивание"
echo "  19. Чат открывается свайпом влево, закрывается вправо/вниз"
echo "  20. Share только в portrait"
echo "  21. Убрана непонятная иконка сверху"
echo "  22. Кнопка участников не перекрывается"
echo "  23. Иконки в Friends опущены ниже"
echo "  24. Заголовок 'Друзья' с количеством"
echo ""
echo "  Audit fixes:"
echo "  - Keychain migration (Yandex tokens)"
echo "  - VideoService: plex/jellyfin/local cases"
echo "  - AppLanguage.englishName computed property"
echo "════════════════════════════════════════════════════════════"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$HOME/Desktop/plink-backend"
IOS_DIR="$HOME/Desktop/plink"

# ── 1. Backend ──
if [ -d "$BACKEND_DIR" ]; then
    echo ""
    echo "🔧 Backend: applying Pack 6 (AI routes)..."
    
    if [ -f "$SCRIPT_DIR/backend/src/routes/ai.ts" ]; then
        cp "$SCRIPT_DIR/backend/src/routes/ai.ts"   "$BACKEND_DIR/src/routes/ai.ts"
        cp "$SCRIPT_DIR/backend/src/index.ts"       "$BACKEND_DIR/src/index.ts"
        
        cd "$BACKEND_DIR"
        git add -A
        git commit -m "Pack 6: AI Assistant endpoints (/api/ai/chat, /api/ai/recommend)

Backend:
- POST /api/ai/chat — universal AI assistant (OpenRouter)
- POST /api/ai/recommend — movie recommendations
- Mode-based system prompts (room_host, movie_search, general)
- Rate limit: 30/min for chat, 10/min for recommend
- Version: 1.6.0" || echo "⚠️ nothing to commit"
        git push
        echo "✅ Backend Pack 6 запушен"
    fi
fi

# ── 2. iOS ──
if [ -d "$IOS_DIR" ]; then
    echo ""
    echo "🔧 iOS: applying Pack 6..."
    
    if [ -f "$SCRIPT_DIR/ios/Plink/Extensions/Color+Theme.swift" ]; then
        # Создать нужные папки
        mkdir -p "$IOS_DIR/Plink/Extensions" \
                 "$IOS_DIR/Plink/Utilities" \
                 "$IOS_DIR/Plink/Models" \
                 "$IOS_DIR/Plink/Views/AI" \
                 "$IOS_DIR/Plink/Views/Components" \
                 "$IOS_DIR/Plink/Views/Home" \
                 "$IOS_DIR/Plink/Views/Room" \
                 "$IOS_DIR/Plink/Views/Settings" \
                 "$IOS_DIR/Plink/Views/Profile" \
                 "$IOS_DIR/Plink/Views/Friends" \
                 "$IOS_DIR/Plink/Resources/en.lproj" \
                 "$IOS_DIR/Plink/Resources/ru.lproj" \
                 "$IOS_DIR/Plink/Resources/zh-Hans.lproj" \
                 "$IOS_DIR/Plink/Resources/es.lproj"
        
        # Audit fixes
        cp "$SCRIPT_DIR/ios/Plink/Utilities/KeychainHelper.swift"  "$IOS_DIR/Plink/Utilities/KeychainHelper.swift"
        cp "$SCRIPT_DIR/ios/Plink/Utilities/AppLanguage.swift"     "$IOS_DIR/Plink/Utilities/AppLanguage.swift"
        cp "$SCRIPT_DIR/ios/Plink/Models/VideoService.swift"       "$IOS_DIR/Plink/Models/VideoService.swift"
        
        # New design
        cp "$SCRIPT_DIR/ios/Plink/Extensions/Color+Theme.swift"    "$IOS_DIR/Plink/Extensions/Color+Theme.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Components/AnimatedGradientBackground.swift" \
           "$IOS_DIR/Plink/Views/Components/AnimatedGradientBackground.swift"
        
        # Bug fixes
        cp "$SCRIPT_DIR/ios/Plink/Views/Home/HomeViewFixed.swift"             "$IOS_DIR/Plink/Views/Home/HomeViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Home/RoomsViewFixed.swift"            "$IOS_DIR/Plink/Views/Home/RoomsViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Home/ServiceSelectionViewFixed.swift" "$IOS_DIR/Plink/Views/Home/ServiceSelectionViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Home/RoomSetupViewFixed.swift"        "$IOS_DIR/Plink/Views/Home/RoomSetupViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Room/RoomViewFixed.swift"             "$IOS_DIR/Plink/Views/Room/RoomViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Settings/SettingsViewFixed.swift"     "$IOS_DIR/Plink/Views/Settings/SettingsViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Profile/ProfileViewFixed.swift"       "$IOS_DIR/Plink/Views/Profile/ProfileViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Friends/FriendsViewFixed.swift"       "$IOS_DIR/Plink/Views/Friends/FriendsViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/AI/AIAssistantView.swift"             "$IOS_DIR/Plink/Views/AI/AIAssistantView.swift"
        
        # Translations
        cp "$SCRIPT_DIR/ios/Plink/Resources/en.lproj/Pack6Additional.strings"      "$IOS_DIR/Plink/Resources/en.lproj/Pack6Additional.strings"
        cp "$SCRIPT_DIR/ios/Plink/Resources/ru.lproj/Pack6Additional.strings"      "$IOS_DIR/Plink/Resources/ru.lproj/Pack6Additional.strings"
        cp "$SCRIPT_DIR/ios/Plink/Resources/zh-Hans.lproj/Pack6Additional.strings" "$IOS_DIR/Plink/Resources/zh-Hans.lproj/Pack6Additional.strings"
        cp "$SCRIPT_DIR/ios/Plink/Resources/es.lproj/Pack6Additional.strings"      "$IOS_DIR/Plink/Resources/es.lproj/Pack6Additional.strings"
        
        cd "$IOS_DIR"
        git add -A
        git commit -m "Pack 6: Bug fixes + UI polish + AI + new design

iOS Bug Fixes:
- Animated background 3x faster + 3-color gradient
- Premium/Plink+ buttons work (open PaywallView)
- Create room: data validation fix
- Settings: removed huge padding after chevrons
- Notifications button opens
- Removed gear icon from ProfileView
- Restored 'Watching Now' and Recommendations on Home
- 'Requests' fits in one line (.lineLimit(1))
- Service selection → goes to room setup (not player)
- Removed 'create room' from video player
- Participants counter: proper Stepper + chips (5/10/15/20)
- Home buttons: expanded by default, collapse after 6 sec idle
- 'Join' button switches to Rooms tab + Join subtab
- AI Assistant working (OpenRouter integration)
- Full RU/EN/ZH/ES translations (Pack6Additional.strings)
- New multi-color design: Purple + Pink + Orange gradients
- Chat button doesn't overlap video collapse
- Chat opens with swipe-left, closes with swipe-right/down
- Share button only in portrait orientation
- Removed unknown top icon
- Participants button not overlapped
- Friends icons lowered
- Friends title shows count

Audit Fixes:
- Keychain migration for legacy Yandex tokens
- VideoService: added plex/jellyfin/local cases
- AppLanguage.englishName computed property" || echo "⚠️ nothing to commit"
        git push
        echo "✅ iOS Pack 6 запушен"
    fi
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ Pack 6 запушен!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "После деплоя:"
echo ""
echo "1. Railway Variables (опционально для AI):"
echo "   OPENROUTER_API_KEY = sk-or-v1-..."
echo "   Получить: https://openrouter.ai/keys"
echo ""
echo "2. Тест AI:"
echo "   TOKEN='ваш_токен'"
echo "   curl -X POST https://plink-backend-production-ef31.up.railway.app/api/ai/chat \\"
echo "     -H 'Authorization: Bearer \$TOKEN' \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"messages\":[{\"role\":\"user\",\"content\":\"Привет!\"}],\"mode\":\"general\"}'"
echo ""
echo "3. В Xcode:"
echo "   - Добавьте новые файлы в проект (drag & drop)"
echo "   - Замените существующие HomeView, SettingsView, ProfileView, FriendsView, RoomView на *Fixed версии"
echo "   - В MainTabView используйте TabRouter.shared для переключения табов"
echo "   - Убедитесь что Info.plist содержит CFBundleLocalizations: [en, ru, zh-Hans, es]"
echo "   - Добавьте NSSupportsLiveActivities = YES (для Pack 5)"
echo ""
echo "4. Если Yandex Auth использовался старым кодом:"
echo "   - Пользователи автоматически мигрируют при первом запуске"
echo "   - KeychainHelper.migrateLegacyTokensIfNeeded() вызовите в RaveCloneApp.init"
