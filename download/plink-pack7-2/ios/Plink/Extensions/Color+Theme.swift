import SwiftUI

// MARK: - Color+Theme (Pack 7.2: строгая и дорогая Premium палитра)
//
// Дизайн-философия:
// ─────────────────
// PREMIUM = Deep Gold + Champagne + Onyx (дорого, строго)
// Каждая фича имеет свой цвет, но все гармонируют:
//
//   BRAND     → Purple (#8B5CF6) — основной brand
//   PREMIUM   → Deep Gold (#D4AF37) + Champagne — премиум
//   ROOMS     → Indigo (#6366F1) — видео/комнаты
//   FRIENDS   → Rose (#F43F5E) — соцсеть
//   PROFILE   → Amber (#F59E0B) — аккаунт
//   AI        → Teal (#14B8A6) — ИИ
//   SETTINGS  → Slate (#64748B) — конфигурация
//   LIVE      → Emerald (#10B981) — онлайн/_live
//   NOTIFS    → Crimson (#DC2626) — уведомления
//   SUCCESS   → Green (#22C55E)
//   WARNING   → Yellow (#EAB308)
//   ERROR     → Red (#EF4444)

extension Color {
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - PREMIUM PALETTE (строгая и дорогая)
    // ═══════════════════════════════════════════════════════════════
    
    /// Deep Gold — основной premium цвет (#D4AF37)
    static let plinkPremiumGold = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    /// Champagne — светлый акцент (#F5E6C8)
    static let plinkChampagne = Color(red: 0.961, green: 0.902, blue: 0.784)
    
    /// Bronze — тёмный gold для depth (#8B5A2B)
    static let plinkBronze = Color(red: 0.545, green: 0.353, blue: 0.169)
    
    /// Platinum — silver accent (#E5E4E2)
    static let plinkPlatinum = Color(red: 0.898, green: 0.894, blue: 0.886)
    
    /// Onyx — глубокий чёрный для premium cards (#0A0A0A)
    static let plinkOnyx = Color(red: 0.039, green: 0.039, blue: 0.039)
    
    /// Premium gradient — деликатный, не "кричащий"
    /// Deep Gold → Bronze (без жёлтых переливов)
    static var plinkPremiumGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.831, green: 0.686, blue: 0.216),  // Deep Gold
                Color(red: 0.620, green: 0.482, blue: 0.137),  // Darker Gold
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Premium subtle gradient — для тонких акцентов
    /// Champagne → Platinum
    static var plinkPremiumSubtle: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.961, green: 0.902, blue: 0.784),  // Champagne
                Color(red: 0.898, green: 0.894, blue: 0.886),  // Platinum
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - FEATURE COLORS (каждая фича — свой цвет)
    // ═══════════════════════════════════════════════════════════════
    
    /// BRAND — Purple (#8B5CF6)
    static let plinkPrimary = Color(red: 0.545, green: 0.361, blue: 0.965)
    
    /// ROOMS — Indigo (#6366F1)
    static let plinkRooms = Color(red: 0.388, green: 0.400, blue: 0.945)
    
    /// FRIENDS — Rose (#F43F5E)
    static let plinkFriends = Color(red: 0.957, green: 0.247, blue: 0.369)
    
    /// PROFILE — Amber (#F59E0B)
    static let plinkProfile = Color(red: 0.961, green: 0.620, blue: 0.043)
    
    /// AI — Teal (#14B8A6)
    static let plinkAI = Color(red: 0.078, green: 0.722, blue: 0.651)
    
    /// SETTINGS — Slate (#64748B)
    static let plinkSettings = Color(red: 0.392, green: 0.455, blue: 0.545)
    
    /// LIVE — Emerald (#10B981)
    static let plinkLive = Color(red: 0.063, green: 0.725, blue: 0.506)
    
    /// NOTIFICATIONS — Crimson (#DC2626)
    static let plinkNotifications = Color(red: 0.863, green: 0.149, blue: 0.149)
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - SEMANTIC
    // ═══════════════════════════════════════════════════════════════
    
    static let plinkSuccess = Color(red: 0.220, green: 0.780, blue: 0.349)
    static let plinkWarning = Color(red: 0.961, green: 0.804, blue: 0.165)
    static let plinkError = Color(red: 0.937, green: 0.286, blue: 0.286)
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - BACKGROUNDS
    // ═══════════════════════════════════════════════════════════════
    
    static let plinkBgPrimary = Color(red: 0.043, green: 0.043, blue: 0.058)
    static let plinkBgSecondary = Color(red: 0.078, green: 0.078, blue: 0.106)
    static let plinkBgTertiary = Color(red: 0.118, green: 0.118, blue: 0.157)
    
    // Premium background — Onyx с лёгким gold tint
    static let plinkBgPremium = Color(red: 0.05, green: 0.04, blue: 0.03)
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - TEXT
    // ═══════════════════════════════════════════════════════════════
    
    static let plinkTextPrimary = Color.white
    static let plinkTextSecondary = Color.white.opacity(0.65)
    static let plinkTextTertiary = Color.white.opacity(0.4)
    
    /// Premium text — Champagne (для премиум блоков)
    static let plinkTextPremium = Color(red: 0.961, green: 0.902, blue: 0.784)
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - GRADIENTS PER FEATURE
    // ═══════════════════════════════════════════════════════════════
    
    /// Brand gradient — Purple → Indigo (для главных CTA)
    static var plinkGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.545, green: 0.361, blue: 0.965),
                Color(red: 0.388, green: 0.400, blue: 0.945),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Rooms gradient — Indigo
    static var plinkRoomsGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.388, green: 0.400, blue: 0.945),
                Color(red: 0.290, green: 0.310, blue: 0.870),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Friends gradient — Rose
    static var plinkFriendsGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.957, green: 0.247, blue: 0.369),
                Color(red: 0.820, green: 0.180, blue: 0.290),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// AI gradient — Teal
    static var plinkAIGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.078, green: 0.722, blue: 0.651),
                Color(red: 0.0, green: 0.580, blue: 0.530),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Profile gradient — Amber
    static var plinkProfileGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.961, green: 0.620, blue: 0.043),
                Color(red: 0.850, green: 0.500, blue: 0.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Settings gradient — Slate
    static var plinkSettingsGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.392, green: 0.455, blue: 0.545),
                Color(red: 0.290, green: 0.350, blue: 0.430),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Background gradient — мягкий, многоцветный
    static var plinkBgGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.043, green: 0.043, blue: 0.058),
                Color(red: 0.058, green: 0.043, blue: 0.078),
                Color(red: 0.043, green: 0.058, blue: 0.078),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MARK: - BACKWARD COMPATIBILITY
    // ═══════════════════════════════════════════════════════════════
    
    static let plinkSecondary = plinkFriends
    static let plinkAccent = plinkProfile
    static let plinkCyan = plinkAI
    
    // Legacy gradients
    static var plinkWarmGradient: LinearGradient { plinkProfileGradient }
    static var plinkCoolGradient: LinearGradient { plinkAIGradient }
    static var plinkRainbow: LinearGradient { plinkPremiumGradient }
    
    // Legacy colors
    static let ravePrimary = plinkPrimary
    static let raveSecondary = plinkFriends
    static let raveAccent = plinkProfile
    static let raveBackground = plinkBgPrimary
    static let raveCardBg = plinkBgSecondary
    static let raveTextPrimary = plinkTextPrimary
    static let raveTextSecondary = plinkTextSecondary
    static let raveSuccess = plinkSuccess
    static let raveError = plinkError
    
    /// Premium legacy
    static let plinkPremium = plinkPremiumGold
}
