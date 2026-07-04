import SwiftUI

// MARK: - Color+Theme (Pack 6: НОВАЯ цветовая палитра — multi-color)
/// Заменяет голубой single-color дизайн на богатый multi-color gradient.
/// 3 основных цвета: Purple (#8B5CF6) + Pink (#EC4899) + Orange (#F59E0B)
/// + акцентный Cyan (#06B6D4) для интерактивных элементов

extension Color {
    // ── Основная палитра ──
    
    /// Primary — Purple
    static let plinkPrimary = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6
    
    /// Secondary — Pink/Magenta
    static let plinkSecondary = Color(red: 0.925, green: 0.282, blue: 0.600) // #EC4899
    
    /// Accent — Orange/Amber
    static let plinkAccent = Color(red: 0.961, green: 0.620, blue: 0.043) // #F59E0B
    
    /// Cyan — для interactive (buttons, links)
    static let plinkCyan = Color(red: 0.024, green: 0.714, blue: 0.831) // #06B6D4
    
    /// Success — Green
    static let plinkSuccess = Color(red: 0.220, green: 0.780, blue: 0.349) // #38C759
    
    /// Warning — Yellow
    static let plinkWarning = Color(red: 0.961, green: 0.804, blue: 0.165) // #F5CA29
    
    /// Error — Red
    static let plinkError = Color(red: 0.937, green: 0.286, blue: 0.286) // #EF4949
    
    // ── Background colors ──
    
    /// Тёмный фон с лёгким пурпурным оттенком
    static let plinkBgPrimary = Color(red: 0.043, green: 0.043, blue: 0.058) // #0B0B0F
    
    /// Чуть светлее — для cards
    static let plinkBgSecondary = Color(red: 0.078, green: 0.078, blue: 0.106) // #14141B
    
    /// Ещё светлее — для inputs
    static let plinkBgTertiary = Color(red: 0.118, green: 0.118, blue: 0.157) // #1E1E28
    
    // ── Text colors ──
    
    static let plinkTextPrimary = Color.white
    static let plinkTextSecondary = Color.white.opacity(0.65)
    static let plinkTextTertiary = Color.white.opacity(0.4)
    
    // ── Backward compatibility (для существующего кода) ──
    static let ravePrimary = plinkPrimary
    static let raveSecondary = plinkSecondary
    static let raveAccent = plinkAccent
    static let raveBackground = plinkBgPrimary
    static let raveCardBg = plinkBgSecondary
    static let raveTextPrimary = plinkTextPrimary
    static let raveTextSecondary = plinkTextSecondary
    static let raveSuccess = plinkSuccess
    static let raveError = plinkError
    
    // ── Gradients ──
    
    /// Основной градиент — Purple → Pink
    static var plinkGradient: LinearGradient {
        LinearGradient(
            colors: [.plinkPrimary, .plinkSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Тёплый градиент — Pink → Orange
    static var plinkWarmGradient: LinearGradient {
        LinearGradient(
            colors: [.plinkSecondary, .plinkAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Прохладный градиент — Purple → Cyan
    static var plinkCoolGradient: LinearGradient {
        LinearGradient(
            colors: [.plinkPrimary, .plinkCyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Радужный градиент — 3 цвета (Purple → Pink → Orange)
    static var plinkRainbow: LinearGradient {
        LinearGradient(
            colors: [.plinkPrimary, .plinkSecondary, .plinkAccent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    /// Фоновый градиент для экранов
    static var plinkBgGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.043, green: 0.043, blue: 0.058),
                Color(red: 0.078, green: 0.043, blue: 0.118),
                Color(red: 0.043, green: 0.078, blue: 0.118),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
