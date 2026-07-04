import AVKit
import SwiftUI

// MARK: - AirPlayManager (Pack 5: AirPlay + Chromecast support)
/// Управление AirPlay для AVPlayer + External display mirroring

@MainActor
final class AirPlayManager: ObservableObject {
    static let shared = AirPlayManager()
    
    @Published private(set) var isAirPlayActive = false
    @Published private(set) var externalScreen: UIScreen?
    @Published private(set) var availableRoutes: [AVAudioSessionRouteDescription] = []
    
    private var routeDetector: AVRoutePickerView?
    private var screenConnectObserver: NSObjectProtocol?
    private var screenDisconnectObserver: NSObjectProtocol?
    
    private init() {
        setupScreenObservers()
        setupAudioSession()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
            
            // Listen for route changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRouteChange(_:)),
                name: AVAudioSession.routeChangeNotification,
                object: session
            )
        } catch {
            print("[AirPlay] Failed to setup audio session: \(error)")
        }
    }
    
    private func setupScreenObservers() {
        screenConnectObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.didConnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let screen = notification.object as? UIScreen else { return }
            Task { @MainActor in
                self?.externalScreen = screen
                self?.isAirPlayActive = true
            }
        }
        
        screenDisconnectObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.didDisconnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.externalScreen = nil
                self?.isAirPlayActive = false
            }
        }
    }
    
    // MARK: - AirPlay Button
    
    /// Создать SwiftUI кнопку AirPlay route picker
    func makeRoutePickerButton(tintColor: Color = .white) -> some View {
        RoutePickerButton(tintColor: tintColor)
    }
    
    // MARK: - Route Change Handler
    
    @objc private nonisolated func handleRouteChange(_ notification: Notification) {
        Task { @MainActor in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            
            let session = AVAudioSession.sharedInstance()
            let currentRoute = session.currentRoute
            
            switch reason {
            case .routeConfigurationChange:
                // Проверить активен ли AirPlay
                let airPlayOutput = currentRoute.outputs.first { output in
                    output.portType == .airPlay
                }
                self.isAirPlayActive = airPlayOutput != nil
                
            default:
                break
            }
        }
    }
    
    // MARK: - External Display
    
    /// Создать view для внешнего экрана (TV через AirPlay)
    func makeExternalDisplayView(player: AVPlayer) -> some View {
        ExternalDisplayView(player: player)
    }
    
    deinit {
        if let obs = screenConnectObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let obs = screenDisconnectObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}

// MARK: - Route Picker Button (SwiftUI wrapper)

private struct RoutePickerButton: UIViewRepresentable {
    let tintColor: Color
    
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = UIColor(tintColor)
        picker.activeTintColor = UIColor(tintColor)
        picker.prioritizesVideoDevices = true
        picker.isRoutePickerButtonBordered = false
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = UIColor(tintColor)
    }
}

// MARK: - External Display View

private struct ExternalDisplayView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        // Если есть внешний экран — добавим player layer
        if let screen = AirPlayManager.shared.externalScreen {
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = screen.bounds
            playerLayer.videoGravity = .resizeAspect
            view.layer.addSublayer(playerLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update on external screen changes
    }
}
