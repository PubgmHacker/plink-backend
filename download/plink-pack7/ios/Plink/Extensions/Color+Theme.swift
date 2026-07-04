import SwiftUI

// MARK: - Color+Theme (Pack 7: разделённые цветовые палитры)
// Проблема: всё одного цвета → выглядит монотонно
// Решение: разные цвета для разных смысловых групп

extension Color {
    // ── BRAND (основной brand color) ──
    static let plinkPrimary = Color(red: 0.545, green: 0.361, blue: 0.965) // Purple #8B5CF6
    
    // ── ACCENT COLORS (каждая фича — свой цвет) ──
    
    /// Rooms / Video — Purple
    static let plinkRooms = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6
    
    /// Friends / Social — Pink
    static let plinkFriends = Color(red: 0.925, green: 0.282, blue: 0.600) // #EC4899
    
    /// Profile / Account — Orange/Amber
    static let plinkProfile = Color(red: 0.961, green: 0.620, blue: 0.043) // #F59E0B
    
    /// AI / Assistant — Cyan/Teal
    static let plinkAI = Color(red: 0.024, green: 0.714, blue: 0.831) // #06B6D4
    
    /// Settings / Configuration — Slate Gray
    static let plinkSettings = Color(red: 0.4, green: 0.45, blue: 0.55) // #66738C
    
    /// Premium / Crown — Gold/Yellow gradient
    static let plinkPremium = Color(red: 0.949, green: 0.773, blue: 0.0) // #F2C500
    
    /// Notifications — Red
    static let plinkNotifications = Color(red: 0.937, green: 0.286, blue: 0.286) // #EF4949
    
    /// Live / Watching now — Green
    static let plinkLive = Color(red: 0.220, green: 0.780, blue: 0.349) // #38C759
    
    // ── Semantic colors ──
    static let plinkSuccess = Color(red: 0.220, green: 0.780, blue: 0.349)
    static let plinkWarning = Color(red: 0.961, green: 0.804, blue: 0.165)
    static let plinkError = Color(red: 0.937, green: 0.286, blue: 0.286)
    
    // ── Background colors ──
    static let plinkBgPrimary = Color(red: 0.043, green: 0.043, blue: 0.058)
    static let plinkBgSecondary = Color(red: 0.078, green: 0.078, blue: 0.106)
    static let plinkBgTertiary = Color(red: 0.118, green: 0.118, blue: 0.157)
    
    // ── Text colors ──
    static let plinkTextPrimary = Color.white
    static let plinkTextSecondary = Color.white.opacity(0.65)
    static let plinkTextTertiary = Color.white.opacity(0.4)
    
    // ── Backward compatibility ──
    static let plinkSecondary = plinkFriends
    static let plinkAccent = plinkProfile
    static let plinkCyan = plinkAI
    
    // ── Gradients per feature ──
    
    /// Brand gradient — Purple → Pink (для CTA buttons)
    static var plinkGradient: LinearGradient {
        LinearGradient(
            colors: [.plinkPrimary, .plinkFriends],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Rooms gradient
    static var plinkRoomsGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.545, green: 0.361, blue: 0.965), Color(red: 0.4, green: 0.3, blue: 0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Friends gradient
    static var plinkFriendsGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.925, green: 0.282, blue: 0.600), Color(red: 0.82, green: 0.22, blue: 0.50)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// AI gradient
    static var plinkAIGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.024, green: 0.714, blue: 0.831), Color(red: 0.0, green: 0.55, blue: 0.75)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Premium gradient — Gold
    static var plinkPremiumGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.949, green: 0.773, blue: 0.0), Color(red: 0.85, green: 0.65, blue: 0.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Profile gradient
    static var plinkProfileGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.961, green: 0.620, blue: 0.043), Color(red: 0.85, green: 0.50, blue: 0.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Background gradient (многоцветный, но мягкий)
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
    
    // Legacy
    static var plinkWarmGradient: LinearGradient { plinkProfileGradient }
    static var plinkCoolGradient: LinearGradient { plinkAIGradient }
    static var plinkRainbow: LinearGradient { plinkPremiumGradient }
    
    // Legacy compat
    static let ravePrimary = plinkPrimary
    static let raveSecondary = plinkFriends
    static let raveAccent = plinkProfile
    static let raveBackground = plinkBgPrimary
    static let raveCardBg = plinkBgSecondary
    static let raveTextPrimary = plinkTextPrimary
    static let raveTextSecondary = plinkTextSecondary
    static let raveSuccess = plinkSuccess
    static let raveError = plinkError
}
