import SwiftUI

// MARK: - SubtitlesManager (Pack 5: Multi-language subtitles + audio tracks)
/// Управление субтитрами и аудиодорожками для AVPlayer

@MainActor
final class SubtitlesManager: ObservableObject {
    static let shared = SubtitlesManager()
    
    @Published private(set) var availableSubtitles: [SubtitleTrack] = []
    @Published private(set) var availableAudioTracks: [AudioTrack] = []
    @Published private(set) var selectedSubtitle: SubtitleTrack?
    @Published private(set) var selectedAudioTrack: AudioTrack?
    
    private var player: AVPlayer?
    private var legibleObserver: NSKeyValueObservation?
    
    private init() {}
    
    // MARK: - Setup
    
    func setup(player: AVPlayer) {
        self.player = player
        loadAvailableTracks()
        observeTrackChanges()
    }
    
    // MARK: - Load Tracks
    
    func loadAvailableTracks() {
        guard let currentItem = player?.currentItem else { return }
        
        // Subtitles / closed captions
        let legibleGroups = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        var subtitles: [SubtitleTrack] = []
        
        if let group = legibleGroups {
            for option in group.options {
                let track = SubtitleTrack(
                    id: option.id ?? UUID().uuidString,
                    name: option.displayName,
                    languageCode: option.locale?.identifier,
                    isDefault: option.id == group.defaultOption?.id
                )
                subtitles.append(track)
            }
        }
        // Add "Off" option
        subtitles.insert(SubtitleTrack(id: "off", name: "Off", languageCode: nil, isDefault: false), at: 0)
        
        availableSubtitles = subtitles
        selectedSubtitle = subtitles.first(where: { $0.isDefault }) ?? subtitles.first
        
        // Audio tracks
        let audibleGroups = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
        var audioTracks: [AudioTrack] = []
        
        if let group = audibleGroups {
            for option in group.options {
                let track = AudioTrack(
                    id: option.id ?? UUID().uuidString,
                    name: option.displayName,
                    languageCode: option.locale?.identifier,
                    isDefault: option.id == group.defaultOption?.id
                )
                audioTracks.append(track)
            }
        }
        availableAudioTracks = audioTracks
        selectedAudioTrack = audioTracks.first(where: { $0.isDefault }) ?? audioTracks.first
    }
    
    // MARK: - Select Track
    
    func selectSubtitle(_ track: SubtitleTrack) {
        guard let player, let currentItem = player.currentItem else { return }
        selectedSubtitle = track
        
        if track.id == "off" {
            currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible).map { group in
                currentItem.select(nil, in: group)
            }
        } else {
            currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible).map { group in
                if let option = group.options.first(where: { $0.id == track.id }) {
                    currentItem.select(option, in: group)
                }
            }
        }
        
        HapticManager.shared.selectionChanged()
    }
    
    func selectAudioTrack(_ track: AudioTrack) {
        guard let player, let currentItem = player.currentItem else { return }
        selectedAudioTrack = track
        
        currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .audible).map { group in
            if let option = group.options.first(where: { $0.id == track.id }) {
                currentItem.select(option, in: group)
            }
        }
        
        HapticManager.shared.selectionChanged()
    }
    
    // MARK: - Observers
    
    private func observeTrackChanges() {
        guard let player else { return }
        
        legibleObserver = player.observe(\.currentLegibleOutput, options: [.new]) { _, _ in
            Task { @MainActor in
                // Update current selection
            }
        }
    }
    
    deinit {
        legibleObserver?.invalidate()
    }
}

// MARK: - Models

struct SubtitleTrack: Identifiable, Hashable {
    let id: String
    let name: String
    let languageCode: String?
    let isDefault: Bool
    
    var flag: String? {
        guard let code = languageCode else { return nil }
        // Convert language code to flag emoji
        // en → 🇬🇧, ru → 🇷🇺, etc.
        switch code.split(separator: "_").first.map(String.init) {
        case "en": return "🇬🇧"
        case "ru": return "🇷🇺"
        case "es": return "🇪🇸"
        case "de": return "🇩🇪"
        case "fr": return "🇫🇷"
        case "it": return "🇮🇹"
        case "ja": return "🇯🇵"
        case "ko": return "🇰🇷"
        case "zh": return "🇨🇳"
        case "ar": return "🇸🇦"
        case "hi": return "🇮🇳"
        case "pt": return "🇵🇹"
        case "tr": return "🇹🇷"
        default: return "🌐"
        }
    }
}

struct AudioTrack: Identifiable, Hashable {
    let id: String
    let name: String
    let languageCode: String?
    let isDefault: Bool
    
    var flag: String? {
        SubtitleTrack(id: id, name: name, languageCode: languageCode, isDefault: isDefault).flag
    }
}
