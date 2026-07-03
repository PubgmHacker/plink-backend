#!/bin/bash
# Plink Pack 7.2: Строгая Premium палитра + все фиксы Pack 7
set -e

echo "════════════════════════════════════════════════════════════"
echo "  Plink Pack 7.2: Строгая Premium палитра"
echo ""
echo "  Premium Palette (строгая и дорогая):"
echo "    - Deep Gold #D4AF37 (основной premium)"
echo "    - Champagne #F5E6C8 (светлый акцент)"
echo "    - Bronze #8B5A2B (depth)"
echo "    - Platinum #E5E4E2 (silver)"
echo "    - Onyx #0A0A0A (premium cards background)"
echo ""
echo "  Feature Colors (каждая фича свой цвет):"
echo "    - Brand    → Purple #8B5CF6"
echo "    - Rooms    → Indigo #6366F1"
echo "    - Friends  → Rose #F43F5E"
echo "    - Profile  → Amber #F59E0B"
echo "    - AI       → Teal #14B8A6"
echo "    - Settings → Slate #64748B"
echo "    - Live     → Emerald #10B981"
echo "    - Notifs   → Crimson #DC2626"
echo ""
echo "  Все фиксы Pack 7:"
echo "    1. Чат — Telegram-style bottom sheet, свайп вниз закрывает"
echo "    2. Настройки — отдельная вкладка таббара"
echo "    3. Фикс двойных нажатий (NavigationLink вместо @State sheet)"
echo "    4. ИИ — в центре таббара (3-я позиция)"
echo "    5. Аватары — обводка только для Premium (Gold) и Admin (Red)"
echo "    6. Кнопки Главная — с надписями, развёрнуты, сворачиваются через 6с"
echo "    7. 'Присоединиться' → переключает на Rooms/Join"
echo "    8. Standard iOS swipe-back gesture для навигации"
echo ""
echo "  Premium design (строгий):"
echo "    - Premium buttons: Onyx bg + Gold border + Gold text"
echo "    - Premium cards: Onyx bg с тонкой Gold границей"
echo "    - Premium avatars: Deep Gold gradient ring"
echo "    - Premium badge: crown на Onyx circle с Gold border"
echo "════════════════════════════════════════════════════════════"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$HOME/Desktop/plink"

if [ -d "$IOS_DIR" ]; then
    echo ""
    echo "🔧 iOS: applying Pack 7.2..."
    
    if [ -f "$SCRIPT_DIR/ios/Plink/Extensions/Color+Theme.swift" ]; then
        mkdir -p "$IOS_DIR/Plink/Extensions" \
                 "$IOS_DIR/Plink/Views/Components" \
                 "$IOS_DIR/Plink/Views/Home" \
                 "$IOS_DIR/Plink/Views/Room" \
                 "$IOS_DIR/Plink/Views/Settings" \
                 "$IOS_DIR/Plink/Views/Profile"
        
        cp "$SCRIPT_DIR/ios/Plink/Extensions/Color+Theme.swift" \
           "$IOS_DIR/Plink/Extensions/Color+Theme.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Components/MainTabViewFixed.swift" \
           "$IOS_DIR/Plink/Views/Components/MainTabViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Components/AvatarView.swift" \
           "$IOS_DIR/Plink/Views/Components/AvatarView.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Home/HomeViewFixed.swift" \
           "$IOS_DIR/Plink/Views/Home/HomeViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Room/RoomViewFixed.swift" \
           "$IOS_DIR/Plink/Views/Room/RoomViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Settings/SettingsViewFixed.swift" \
           "$IOS_DIR/Plink/Views/Settings/SettingsViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Profile/ProfileViewFixed.swift" \
           "$IOS_DIR/Plink/Views/Profile/ProfileViewFixed.swift"
        
        cd "$IOS_DIR"
        git add -A
        git commit -m "Pack 7.2: Строгая Premium палитра + все фиксы Pack 7

Premium Palette (строгая и дорогая):
- Deep Gold #D4AF37 — основной premium цвет
- Champagne #F5E6C8 — светлый акцент
- Bronze #8B5A2B — depth
- Platinum #E5E4E2 — silver accent
- Onyx #0A0A0A — premium cards background

Premium Design:
- Premium buttons: Onyx bg + Gold border + Gold text (строгий)
- Premium cards: Onyx bg с тонкой Gold границей
- Premium avatars: Deep Gold gradient ring
- Premium badge: crown на Onyx circle с Gold border

Feature Colors (каждая фича свой цвет):
- Brand → Purple #8B5CF6
- Rooms → Indigo #6366F1
- Friends → Rose #F43F5E
- Profile → Amber #F59E0B
- AI → Teal #14B8A6
- Settings → Slate #64748B
- Live → Emerald #10B981
- Notifs → Crimson #DC2626

Bug Fixes:
- Чат: Telegram-style bottom sheet, свайп вниз закрывает
- Настройки: отдельная вкладка таббара (5-я позиция)
- Фикс двойных нажатий (NavigationLink вместо @State sheet)
- ИИ: в центре таббара (3-я позиция)
- Аватары: обводка только для Premium (Gold) и Admin (Red)
- Кнопки Главная: с надписями, развёрнуты, сворачиваются через 6с
- 'Присоединиться' → переключает на Rooms/Join
- Standard iOS swipe-back gesture для навигации" || echo "⚠️ nothing to commit"
        git push
        echo "✅ iOS Pack 7.2 запушен"
    fi
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ Pack 7.2 запушен!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "В Xcode:"
echo "  1. Замените файлы на *Fixed версии (drag & drop)"
echo "  2. Добавьте AvatarView.swift в проект"
echo "  3. В RaveCloneApp.swift используйте MainTabViewFixed()"
echo "  4. Cmd+B → Cmd+R"
echo ""
echo "Тест Premium дизайна:"
echo "  - Premium кнопки: чёрные с gold границей и gold текстом"
echo "  - Premium иконки: crown на чёрном кружке с gold границей"
echo "  - Аватар Premium: gold обводка + crown badge"
echo "  - Аватар Admin: red обводка + shield badge"
echo "  - Аватар обычного юзера: без обводки"
echo ""
echo "Тест цветовых палитр:"
echo "  - Таббар tint меняется в зависимости от выбранной вкладки"
echo "  - Главная: Создать (Indigo), Присоединиться (Rose)"
echo "  - Смотрят сейчас (Emerald), Рекомендации (Teal)"
echo "  - Plink+ кнопка (Onyx + Gold)"
echo "  - Settings: каждая иконка своего цвета"
