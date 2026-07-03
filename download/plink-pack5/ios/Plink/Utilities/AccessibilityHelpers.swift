import SwiftUI

// MARK: - AccessibilityHelpers (Pack 5: VoiceOver + accessibility)

struct AccessibilityHelpers {
    static func button(label: String, hint: String? = nil) -> some ViewModifier {
        ButtonAccessibilityModifier(label: label, hint: hint)
    }
}

struct ButtonAccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
}

extension View {
    func accessibleButton(_ label: String, hint: String? = nil) -> some View {
        modifier(AccessibilityHelpers.button(label: label, hint: hint))
    }
    
    func accessibilityHeader() -> some View {
        self.accessibilityAddTraits(.isHeader)
    }
    
    func accessibilitySelected(_ isSelected: Bool) -> some View {
        self.accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
    
    func playbackAccessibility(isPlaying: Bool, currentTime: TimeInterval, duration: TimeInterval) -> some View {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        
        let current = formatter.string(from: currentTime) ?? "0:00"
        let total = formatter.string(from: duration) ?? "0:00"
        
        return self
            .accessibilityLabel(
                isPlaying ? "Воспроизведение, \(current) из \(total)" : "Пауза, \(current) из \(total)"
            )
            .accessibilityHint("Двойной тап для \(isPlaying ? "паузы" : "воспроизведения")")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    NotificationCenter.default.post(name: .seekForward, object: nil)
                case .decrement:
                    NotificationCenter.default.post(name: .seekBackward, object: nil)
                default:
                    break
                }
            }
    }
    
    func participantAccessibility(name: String, isHost: Bool, isSpeaking: Bool) -> some View {
        let role = isHost ? "хост" : "участник"
        let speaking = isSpeaking ? ", говорит" : ""
        return self.accessibilityLabel("\(name), \(role)\(speaking)")
    }
    
    func reactionAccessibility(emoji: String, count: Int) -> some View {
        self.accessibilityLabel("Реакция \(emoji), \(count) раз")
    }
}

extension Notification.Name {
    static let seekForward = Notification.Name("seekForward")
    static let seekBackward = Notification.Name("seekBackward")
}

struct MotionSensitivityModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation
    
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.animation(animation, value: UUID())
        }
    }
}

extension View {
    func motionSensitive(_ animation: Animation = .easeInOut) -> some View {
        modifier(MotionSensitivityModifier(animation: animation))
    }
}
