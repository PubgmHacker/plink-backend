import Foundation
import SwiftUI

// MARK: - VideoService (Pack 6: добавлены plex, jellyfin, local)

enum VideoService: String, CaseIterable, Identifiable, Sendable, Codable {
    case youtube
    case vk
    case rutube
    case netflix
    case disney
    case browser
    case customURL = "custom"
    case kinopoisk
    case ivi
    case okko
    case wink
    case start
    case premier
    case smotrim
    case kion
    case plex
    case jellyfin
    case local
    
    var id: String { rawValue }
    
    var group: Group {
        switch self {
        case .youtube, .vk, .rutube, .netflix, .disney: return .direct
        case .browser, .customURL: return .universal
        case .kinopoisk, .ivi, .okko, .wink, .start, .premier, .smotrim, .kion: return .cinema
        case .plex, .jellyfin, .local: return .universal
        }
    }
    
    var playbackMode: PlaybackMode {
        switch group {
        case .direct: return .directStream
        case .universal: return .directStream
        case .cinema: return .webview
        }
    }
    
    var displayName: String {
        switch self {
        case .youtube: return "YouTube"
        case .vk: return "VK Видео"
        case .rutube: return "RuTube"
        case .netflix: return "Netflix"
        case .disney: return "Disney+"
        case .browser: return "Браузер"
        case .customURL: return "Ссылка"
        case .kinopoisk: return "Кинопоиск"
        case .ivi: return "Иви"
        case .okko: return "Okko"
        case .wink: return "Wink"
        case .start: return "Start"
        case .premier: return "Premier"
        case .smotrim: return "Смотрим"
        case .kion: return "КИОН"
        case .plex: return "Plex"
        case .jellyfin: return "Jellyfin"
        case .local: return "Локально"
        }
    }
    
    var iconName: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .vk: return "play.tv.fill"
        case .rutube: return "play.circle.fill"
        case .netflix: return "n.square.fill"
        case .disney: return "d.square.fill"
        case .browser: return "safari.fill"
        case .customURL: return "link"
        case .kinopoisk: return "film.fill"
        case .ivi: return "play.square.fill"
        case .okko: return "tv.fill"
        case .wink: return "eye.fill"
        case .start: return "play.circle"
        case .premier: return "star.fill"
        case .smotrim: return "antenna.radiowaves.left.and.right"
        case .kion: return "tv.and.mediabox"
        case .plex: return "server.rack"
        case .jellyfin: return "externaldrive.connected.to.line.below"
        case .local: return "internaldrive"
        }
    }
    
    var brandColor: Color {
        switch self {
        case .youtube: return Color(red: 1.0, green: 0.0, blue: 0.0)
        case .vk: return Color(red: 0.267, green: 0.518, blue: 0.961)
        case .rutube: return Color(red: 0.0, green: 0.0, blue: 0.0)
        case .netflix: return Color(red: 0.898, green: 0.137, blue: 0.137)
        case .disney: return Color(red: 0.18, green: 0.404, blue: 0.745)
        case .plex: return Color(red: 0.949, green: 0.773, blue: 0.0)
        case .jellyfin: return Color(red: 0.0, green: 0.541, blue: 0.808)
        default: return .plinkPrimary
        }
    }
    
    init?(mediaSource: MediaItem.MediaSource) {
        switch mediaSource {
        case .youtube: self = .youtube
        case .plex: self = .plex
        case .jellyfin: self = .jellyfin
        case .local: self = .local
        case .url: return nil
        }
    }
    
    enum Group: String, CaseIterable, Identifiable {
        case direct
        case universal
        case cinema
        
        var id: String { rawValue }
        
        @MainActor
        var title: String {
            let l = LocalizationManager.shared
            switch self {
            case .direct: return l.string(.createSource)
            case .universal: return l.string(.createVideoLink)
            case .cinema: return l.string(.serviceCinemas)
            }
        }
    }
    
    static func services(in group: Group) -> [VideoService] {
        allCases.filter { $0.group == group }
    }
}

enum PlaybackMode: String, Sendable {
    case directStream
    case webview
}
