#!/bin/bash
# Plink Pack 7.1: Avatar ring + ИИ в центре таббара
set -e

echo "════════════════════════════════════════════════════════════"
echo "  Plink Pack 7.1: Avatar + TabBar fixes"
echo ""
echo "  Fixes:"
echo "  1. Убрана обводка аватара у обычных юзеров"
echo "     (только Premium → Gold, Admin/Founder → Red)"
echo "  2. ИИ перемещён в центр таббара (3-я позиция)"
echo "     Порядок: Главная → Комнаты → ИИ → Друзья → Настройки"
echo "  3. Добавлен AvatarView компонент (reusable)"
echo "  4. Добавлен UserRole enum"
echo "════════════════════════════════════════════════════════════"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$HOME/Desktop/plink"

if [ -d "$IOS_DIR" ]; then
    echo ""
    echo "🔧 iOS: applying Pack 7.1..."
    
    if [ -f "$SCRIPT_DIR/ios/Plink/Views/Components/MainTabViewFixed.swift" ]; then
        mkdir -p "$IOS_DIR/Plink/Views/Components" \
                 "$IOS_DIR/Plink/Views/Profile"
        
        cp "$SCRIPT_DIR/ios/Plink/Views/Components/MainTabViewFixed.swift" \
           "$IOS_DIR/Plink/Views/Components/MainTabViewFixed.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Components/AvatarView.swift" \
           "$IOS_DIR/Plink/Views/Components/AvatarView.swift"
        cp "$SCRIPT_DIR/ios/Plink/Views/Profile/ProfileViewFixed.swift" \
           "$IOS_DIR/Plink/Views/Profile/ProfileViewFixed.swift"
        
        cd "$IOS_DIR"
        git add -A
        git commit -m "Pack 7.1: Avatar ring (Premium/Admin only) + AI tab in center

iOS Fixes:
- AvatarView: ring только для Premium (Gold) и Admin/Founder (Red)
  Обычные юзеры — без обводки
- Premium badge: коронка внизу справа
- Admin badge: щит внизу справа
- TabBar: ИИ перемещён в центр (3-я позиция)
  Порядок: Главная → Комнаты → ИИ → Друзья → Настройки
- ProfileView: использует AvatarView
- UserRole enum добавлен (user/moderator/admin/founder)" || echo "⚠️ nothing to commit"
        git push
        echo "✅ iOS Pack 7.1 запушен"
    fi
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ Pack 7.1 запушен!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "В Xcode:"
echo "  1. Замените MainTabViewFixed.swift и ProfileViewFixed.swift"
echo "  2. Добавьте AvatarView.swift в проект (drag & drop)"
echo "  3. Замените существующие аватары в коде на AvatarView(...)"
echo "  4. Подставьте реальные значения isPremium/role из AuthService"
echo "  5. Cmd+B → Cmd+R"
