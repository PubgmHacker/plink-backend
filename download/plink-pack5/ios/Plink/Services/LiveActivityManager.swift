import WidgetKit
import ActivityKit
import SwiftUI

// MARK: - Live Activity для активной комнаты (Pack 5: Dynamic Island)

@available(iOS 16.1, *)
struct PlinkRoomActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var roomName: String
        var participantCount: Int
        var mediaTitle: String
        var isPlaying: Bool
        var currentTime: Double
        var duration: Double
    }
    
    var roomCode: String
    var hostName: String
}

@available(iOS 16.1, *)
struct PlinkRoomActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlinkRoomActivityAttributes.self) { context in
            // Lock Screen / Banner view
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: context.state.isPlaying ? "play.fill" : "pause.fill")
                        .font(.title3)
                        .foregroundStyle(.purple)
                    
                    Text(context.state.mediaTitle)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(context.attributes.roomCode)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.purple.opacity(0.2), in: Capsule())
                }
                
                HStack {
                    Text(context.state.roomName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Label("\(context.state.participantCount)", systemImage: "person.2.fill")
                        .font(.caption)
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.gray.opacity(0.3))
                        
                        Capsule()
                            .fill(.purple)
                            .frame(width: geo.size.width * progress(context.state))
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text(formatTime(context.state.currentTime))
                    Spacer()
                    Text(formatTime(context.state.duration))
                }
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.6))
            .activitySystemActionForegroundColor(Color.white)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPlaying ? "play.circle.fill" : "pause.circle.fill")
                        .font(.title)
                        .foregroundStyle(.purple)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text(context.attributes.roomCode)
                            .font(.headline.monospaced())
                        Label("\(context.state.participantCount)", systemImage: "person.2.fill")
                            .font(.caption)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        Text(context.state.mediaTitle)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Text(context.state.roomName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(formatTime(context.state.currentTime))
                        Spacer()
                        Button {
                            // Play/pause action
                        } label: {
                            Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        }
                        Spacer()
                        Text(formatTime(context.state.duration))
                    }
                    .font(.caption.monospaced())
                }
            } compactLeading: {
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.purple)
            } compactTrailing: {
                Text(context.attributes.roomCode.prefix(4))
                    .font(.caption2.monospaced())
            } minimal: {
                Image(systemName: context.state.isPlaying ? "play.fill" : "pause.fill")
                    .foregroundStyle(.purple)
            }
        }
    }
    
    private func progress(_ state: PlinkRoomActivityAttributes.ContentState) -> CGFloat {
        guard state.duration > 0 else { return 0 }
        return CGFloat(state.currentTime / state.duration)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Live Activity Manager

@available(iOS 16.1, *)
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<PlinkRoomActivityAttributes>?
    
    private init() {}
    
    func startActivity(
        roomCode: String,
        hostName: String,
        roomName: String,
        participantCount: Int,
        mediaTitle: String,
        isPlaying: Bool,
        currentTime: Double,
        duration: Double
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        // End existing activity if any
        await endActivity()
        
        let attributes = PlinkRoomActivityAttributes(
            roomCode: roomCode,
            hostName: hostName
        )
        
        let state = PlinkRoomActivityAttributes.ContentState(
            roomName: roomName,
            participantCount: participantCount,
            mediaTitle: mediaTitle,
            isPlaying: isPlaying,
            currentTime: currentTime,
            duration: duration
        )
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            print("✅ Live Activity started: \(roomCode)")
        } catch {
            print("❌ Live Activity failed: \(error)")
        }
    }
    
    func updateActivity(
        participantCount: Int? = nil,
        mediaTitle: String? = nil,
        isPlaying: Bool? = nil,
        currentTime: Double? = nil,
        duration: Double? = nil
    ) async {
        guard let activity = currentActivity else { return }
        
        let currentState = activity.contentState
        let newState = PlinkRoomActivityAttributes.ContentState(
            roomName: currentState.roomName,
            participantCount: participantCount ?? currentState.participantCount,
            mediaTitle: mediaTitle ?? currentState.mediaTitle,
            isPlaying: isPlaying ?? currentState.isPlaying,
            currentTime: currentTime ?? currentState.currentTime,
            duration: duration ?? currentState.duration
        )
        
        await activity.update(.init(state: newState, staleDate: nil))
    }
    
    func endActivity() async {
        guard let activity = currentActivity else { return }
        await activity.end(dismissalPolicy: .immediate)
        currentActivity = nil
        print("✅ Live Activity ended")
    }
}
