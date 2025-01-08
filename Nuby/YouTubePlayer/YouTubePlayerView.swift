import SwiftUI
import WebKit
import os.log

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    @ObservedObject var webViewStore: WebViewStore
    @Binding var currentVideoTime: TimeInterval
    @Binding var isPlayerReady: Bool
    @Binding var playerState: Int
    @Binding var playbackQuality: String
    @Binding var playbackRate: Double
    let onError: (String) -> Void
    
    // Configuration options
    var playerVars: [String: Any]
    var height: CGFloat = 300
    var width: CGFloat = .infinity
    
    init(videoID: String,
         webViewStore: WebViewStore,
         currentVideoTime: Binding<TimeInterval>,
         isPlayerReady: Binding<Bool>,
         playerState: Binding<Int> = .constant(0),
         playbackQuality: Binding<String> = .constant("default"),
         playbackRate: Binding<Double> = .constant(1.0),
         playerVars: [String: Any] = [:],
         height: CGFloat = 300,
         width: CGFloat = .infinity,
         onError: @escaping (String) -> Void) {
        self.videoID = videoID
        self.webViewStore = webViewStore
        self._currentVideoTime = currentVideoTime
        self._isPlayerReady = isPlayerReady
        self._playerState = playerState
        self._playbackQuality = playbackQuality
        self._playbackRate = playbackRate
        self.playerVars = playerVars
        self.height = height
        self.width = width
        self.onError = onError
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = webViewStore.createWebView(with: configuration, coordinator: context.coordinator)
        webView.navigationDelegate = context.coordinator
        
        loadYouTubePlayer(webView)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload if the video ID changes
        if context.coordinator.currentVideoID != videoID {
            context.coordinator.currentVideoID = videoID
            loadYouTubePlayer(webView)
        }
        
        // Update player configuration if needed
        if context.coordinator.lastKnownPlaybackRate != playbackRate {
            context.coordinator.setPlaybackRate(webView, rate: playbackRate)
        }
    }
    
    private func loadYouTubePlayer(_ webView: WKWebView) {
        let html = YouTubePlayerHTML.generateHTML(videoID: videoID, playerVars: playerVars)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com")!)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: YouTubePlayerView
        var timeUpdateTimer: Timer?
        var lastKnownTime: TimeInterval = 0
        var lastKnownPlaybackRate: Double = 1.0
        var pendingSeek: TimeInterval?
        var currentVideoID: String
        var isInitialLoad = true
        
        init(parent: YouTubePlayerView) {
            self.parent = parent
            self.currentVideoID = parent.videoID
            super.init()
        }
        
        // YouTube Player Functions
        func playVideo(_ webView: WKWebView) {
            evaluatePlayerCommand(webView, command: "playVideo()")
        }
        
        func pauseVideo(_ webView: WKWebView) {
            evaluatePlayerCommand(webView, command: "pauseVideo()")
        }
        
        func stopVideo(_ webView: WKWebView) {
            evaluatePlayerCommand(webView, command: "stopVideo()")
        }
        
        func seekTo(_ webView: WKWebView, seconds: TimeInterval, allowSeekAhead: Bool = true) {
            evaluatePlayerCommand(webView, command: "seekTo(\(seconds), \(allowSeekAhead))")
        }
        
        func loadVideoById(_ webView: WKWebView, videoId: String, startSeconds: TimeInterval? = nil) {
            var command = "loadVideoById('\(videoId)'"
            if let startSeconds = startSeconds {
                command += ", \(startSeconds)"
            }
            command += ")"
            evaluatePlayerCommand(webView, command: command)
        }
        
        func cueVideoById(_ webView: WKWebView, videoId: String, startSeconds: TimeInterval? = nil) {
            var command = "cueVideoById('\(videoId)'"
            if let startSeconds = startSeconds {
                command += ", \(startSeconds)"
            }
            command += ")"
            evaluatePlayerCommand(webView, command: command)
        }
        
        func setPlaybackRate(_ webView: WKWebView, rate: Double) {
            evaluatePlayerCommand(webView, command: "setPlaybackRate(\(rate))")
            lastKnownPlaybackRate = rate
        }
        
        func getAvailablePlaybackRates(_ webView: WKWebView) {
            evaluatePlayerCommand(webView, command: "getAvailablePlaybackRates()")
        }
        
        func setSize(_ webView: WKWebView, width: Int, height: Int) {
            evaluatePlayerCommand(webView, command: "setSize(\(width), \(height))")
        }
        
        func getVideoLoadedFraction(_ webView: WKWebView) {
            evaluatePlayerCommand(webView, command: "getVideoLoadedFraction()")
        }
        
        func getPlayerState(_ webView: WKWebView) {
            evaluatePlayerCommand(webView, command: "getPlayerState()")
        }
        
        func getCurrentTime(_ webView: WKWebView) {
            evaluatePlayerCommand(webView, command: "getCurrentTime()")
        }
        
        func getDuration(_ webView: WKWebView) {
            evaluatePlayerCommand(webView, command: "getDuration()")
        }
        
        private func evaluatePlayerCommand(_ webView: WKWebView, command: String) {
            let javascript = "player.\(command);"
            webView.evaluateJavaScript(javascript) { [weak self] result, error in
                if let error = error {
                    self?.parent.onError("Error executing \(command): \(error.localizedDescription)")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Logger.log("WebView finished loading", level: .debug)
            
            // Only seek on subsequent loads, not the initial load
            if !isInitialLoad {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if self.lastKnownTime > 0 {
                        self.seekToTime(webView, time: self.lastKnownTime)
                    }
                }
            }
            isInitialLoad = false
        }
        
        private func seekToTime(_ webView: WKWebView, time: TimeInterval) {
            lastKnownTime = time
            pendingSeek = time
            
            let javascript = "window.seekVideo(\(time));"
            webView.evaluateJavaScript(javascript) { [weak self] result, error in
                if let error = error {
                    Logger.log("Error seeking video: \(error.localizedDescription)", level: .error)
                    self?.parent.onError("Error seeking video: \(error.localizedDescription)")
                }
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let messageString = message.body as? String,
                  let data = messageString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return
            }
            
            guard let event = json["event"] as? String else { return }
            
            DispatchQueue.main.async { [weak self] in
                switch event {
                case "ready":
                    self?.parent.isPlayerReady = true
                case "stateChange":
                    if let state = json["state"] as? Int {
                        self?.parent.playerState = state
                    }
                case "timeUpdate":
                    if let time = json["time"] as? TimeInterval {
                        self?.lastKnownTime = time
                        self?.parent.currentVideoTime = time
                    }
                case "playbackQualityChange":
                    if let quality = json["quality"] as? String {
                        self?.parent.playbackQuality = quality
                    }
                case "playbackRateChange":
                    if let rate = json["rate"] as? Double {
                        self?.parent.playbackRate = rate
                    }
                case "error":
                    if let error = json["error"] as? String {
                        self?.parent.onError(error)
                    }
                default:
                    break
                }
            }
        }
        
        func startTimeUpdates(_ webView: WKWebView) {
            timeUpdateTimer?.invalidate()
            timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateCurrentTime(webView)
            }
        }
        
        private func updateCurrentTime(_ webView: WKWebView) {
            let javascript = "player.getCurrentTime();"
            webView.evaluateJavaScript(javascript) { [weak self] result, error in
                if let time = result as? Double {
                    DispatchQueue.main.async {
                        self?.parent.currentVideoTime = time
                        self?.lastKnownTime = time
                    }
                }
            }
        }
        
        deinit {
            timeUpdateTimer?.invalidate()
        }
    }
}
