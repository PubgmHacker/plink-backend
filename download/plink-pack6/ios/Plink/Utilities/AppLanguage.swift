import SwiftUI

// MARK: - AppLanguage (Pack 6: englishName computed property)

enum AppLanguage: String, CaseIterable, Codable {
    case russian = "ru"
    case english = "en"
    case chinese = "zh-Hans"
    case spanish = "es"
    case german = "de"
    case french = "fr"
    
    /// Локализованное название языка (на самом языке)
    var nativeName: String {
        switch self {
        case .russian: return "Русский"
        case .english: return "English"
        case .chinese: return "中文"
        case .spanish: return "Español"
        case .german: return "Deutsch"
        case .french: return "Français"
        }
    }
    
    /// English representation (Pack 6 fix)
    var englishName: String {
        switch self {
        case .russian: return "Russian"
        case .english: return "English"
        case .chinese: return "Chinese"
        case .spanish: return "Spanish"
        case .german: return "German"
        case .french: return "French"
        }
    }
    
    /// Flag emoji
    var flag: String {
        switch self {
        case .russian: return "🇷🇺"
        case .english: return "🇬🇧"
        case .chinese: return "🇨🇳"
        case .spanish: return "🇪🇸"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        }
    }
    
    /// Locale для этого языка
    var locale: Locale {
        Locale(identifier: rawValue)
    }
}
