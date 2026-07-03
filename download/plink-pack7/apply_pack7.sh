#!/bin/bash
# Plink Pack 7: UI/UX Polish — swipe gestures + color palette + Settings tab
set -e

echo "════════════════════════════════════════════════════════════"
echo "  Plink Pack 7: UI/UX Polish"
echo ""
echo "  Fixes:"
echo "  1. Chat in room — Telegram-style bottom sheet"
echo "     Свайп вниз из любого места закрывает (не только с верха)"
echo "  2. Разделы настроек — стандартный iOS swipe-back gesture"
echo "     (свайп слева-направо для возврата назад)"
echo "  3. Settings — отдельная вкладка в таббаре (не выдвижное окно)"
echo "  4. Фикс двойных нажатий (через NavigationLink без @State sheet)"
echo "  5. Разделённые цветовые палитры:"
echo "     - Rooms → Purple"
echo "     - Friends → Pink"
echo "     - Profile → Orange"
echo "     - AI → Cyan"
echo "     - Settings → Slate"
echo "     - Premium → Gold"
echo "     - Live → Green"
echo "     - Notifications → Red"
echo "════════════════════════════════════════════════════════════"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$HOME/Desktop/plink"

if [ -d "$IOS_DIR" ]; then
    echo ""
    echo "🔧 iOS: applying Pack 7..."
    
    if [ -f "$SCRIPT_DIR/ios/Plink/Extensions/Color+Theme.swift" ]; then
        mkdir -p "$IOS_DIR/Plink/Extensions" \
                 "$IOS_DIR/Plink/Views/Components" \
                 "$IOS_DIR/Plink/Views/Home" \
                 "$IOS_DIR/Plink/Views/Room" \
                 "$IOS_DIR/Plink/Views/Settings"
        
        cp "$SCRIPT_DIR/ios/Plink/Extensions/Color+Theme.swift" \
           "$IOS_DIR/Plink/Extensions/Color+Theme.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Components/MainTabViewFixed.swift" \
           "$IOS_DIR/Plink/Views/Components/MainTabViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Home/HomeViewFixed.swift" \
           "$IOS_DIR/Plink/Views/Home/HomeViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Room/RoomViewFixed.swift" \
           "$IOS_DIR/Plink/Views/Room/RoomViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Settings/SettingsViewFixed.swift" \
           "$IOS_DIR/Plink/Views/Settings/SettingsViewFixed.swift"
        
        cd "$IOS_DIR"
        git add -A
        git commit -m "Pack 7: UI/UX polish — Telegram-style swipe + color palette + Settings tab

iOS Fixes:
- Chat: bottom sheet (Telegram-style), swipe down from anywhere to close
- Settings: separate tab in TabBar (not modal sheet)
- Navigation: standard iOS swipe-back gesture (left-to-right)
- Fixed double-tap bug (NavigationLink instead of @State sheet)
- Separated color palettes per feature:
  * Rooms → Purple (#8B5CF6)
  * Friends → Pink (#EC4899)
  * Profile → Orange (#F59E0B)
  * AI → Cyan (#06B6D4)
  * Settings → Slate Gray (#66738C)
  * Premium → Gold (#F2C500)
  * Live → Green (#38C759)
  * Notifications → Red (#EF4949)
- Each tab has its own color (no longer all purple)
- HomeView: Create=Purple, Join=Pink, Watching=Green, Recs=Cyan, Plink+=Gold
- Color+Theme: 8 distinct colors + gradients per feature" || echo "⚠️ nothing to commit"
        git push
        echo "✅ iOS Pack 7 запушен"
    fi
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ Pack 7 запушен!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "В Xcode:"
echo "  1. Замените существующие файлы на *Fixed версии:"
echo "     - MainTabView → MainTabViewFixed (переименовать)"
echo "     - HomeView → HomeViewFixed"
echo "     - RoomView → RoomViewFixed"
echo "     - SettingsView → SettingsViewFixed"
echo "  2. Убедитесь что TabRouter.shared используется через @EnvironmentObject"
echo "  3. Соберите (Cmd+B) — должно быть без ошибок"
echo "  4. Тест свайпов:"
echo "     - В комнате: открыть чат → свайп вниз → закрылся"
echo "     - В настройках: тапнуть 'Конфиденциальность' → свайп слева-направо → вернулись"
echo "     - В таббаре: 5 вкладок (Главная, Комнаты, Друзья, ИИ, Настройки)"
echo "  5. Тест цветов:"
echo "     - Главная: кнопки разных цветов (Purple, Pink)"
echo "     - Таббар: иконки подсвечиваются brand color"
echo "     - ИИ: Cyan акценты"
echo "     - Premium: Gold"
