import SwiftUI
import WebKit

// MARK: - NetflixPlayerView (Pack 3: WebView с JS injection)
/// WebView для Netflix/Disney+/HBO с синхронизацией через JS-bridge.
///
/// Как это работает:
/// 1. Открывает streaming-сайту в WKWebView
/// 2. Юзер сам логинится своим аккаунтом
/// 3. JS-инжекция читает состояние плеера (play/pause/seek)
/// 4. SyncEngine получает события и синхронизирует с комнатой

struct NetflixPlayerView: UIViewRepresentable {
    let url: URL
    let onPlaybackState: (PlaybackState) -> Void
    
    @Binding var syncCommand: SyncCommand?
    
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: NetflixPlayerView
        var webView: WKWebView?
        
        init(_ parent: NetflixPlayerView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            
            let state = PlaybackState(
                currentTime: body["currentTime"] as? Double ?? 0,
                isPlaying: body["isPlaying"] as? Bool ?? false,
                duration: body["duration"] as? Double ?? 0
            )
            
            DispatchQueue.main.async {
                self.parent.onPlaybackState(state)
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Инжектируем JS-скрипт для чтения состояния плеера Netflix
            let script = """
            (function() {
                // Netflix player API
                function getNetflixPlayer() {
                    if (window.netflix && window.netflix.appContext) {
                        return window.netflix.appContext.state.playerApp.getAPI().videoPlayer;
                    }
                    return null;
                }
                
                // Disney+ / HBO / Amazon Prime — общий паттерн через <video>
                function getVideoElement() {
                    return document.querySelector('video');
                }
                
                // Отправляем состояние в iOS каждые 500ms
                setInterval(function() {
                    var state = { currentTime: 0, isPlaying: false, duration: 0 };
                    
                    // Попробовать Netflix API
                    var netflixPlayer = getNetflixPlayer();
                    if (netflixPlayer) {
                        var sessionId = netflixPlayer.getAllPlayers()[0];
                        if (sessionId) {
                            state.currentTime = netflixPlayer.getCurrentTime(sessionId) / 1000;
                            state.isPlaying = !netflixPlayer.isPaused(sessionId);
                            state.duration = netflixPlayer.getDuration(sessionId) / 1000;
                        }
                    } else {
                        // Fallback: <video> element
                        var video = getVideoElement();
                        if (video) {
                            state.currentTime = video.currentTime;
                            state.isPlaying = !video.paused && !video.ended;
                            state.duration = video.duration;
                        }
                    }
                    
                    window.webkit.messageHandlers.sync.postMessage(state);
                }, 500);
                
                // Слушаем команды от iOS
                window.plinkSync = {
                    play: function() {
                        var video = getVideoElement();
                        if (video) video.play();
                        var np = getNetflixPlayer();
                        if (np) np.play(np.getAllPlayers()[0]);
                    },
                    pause: function() {
                        var video = getVideoElement();
                        if (video) video.pause();
                        var np = getNetflixPlayer();
                        if (np) np.pause(np.getAllPlayers()[0]);
                    },
                    seek: function(time) {
                        var video = getVideoElement();
                        if (video) video.currentTime = time;
                        var np = getNetflixPlayer();
                        if (np) np.seek(np.getAllPlayers()[0], time * 1000);
                    }
                };
            })();
            """
            
            webView.evaluateJavaScript(script, in: nil, in: .defaultClient)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "sync")
        config.userContentController = userContentController
        config.userContentController.addUserScript(
            WKUserScript(
                source: "",
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        
        context.coordinator.webView = webView
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Применяем sync команду от SyncEngine
        if let cmd = syncCommand {
            switch cmd {
            case .play:
                webView.evaluateJavaScript("window.plinkSync.play();")
            case .pause:
                webView.evaluateJavaScript("window.plinkSync.pause();")
            case .seek(let time):
                webView.evaluateJavaScript("window.plinkSync.seek(\(time));")
            }
            DispatchQueue.main.async {
                self.syncCommand = nil
            }
        }
    }
}

// MARK: - Playback State

struct PlaybackState {
    let currentTime: Double
    let isPlaying: Bool
    let duration: Double
}

// MARK: - Sync Command

enum SyncCommand {
    case play
    case pause
    case seek(time: Double)
}
