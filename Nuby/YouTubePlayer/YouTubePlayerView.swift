import SwiftUI
import WebKit
import os.log

struct YouTubePlayerView: UIViewRepresentable {
    // MARK: - Properties
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
    
    // MARK: - Initialization
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
    
    // MARK: - UIViewRepresentable
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Configure JavaScript using WKWebpagePreferences
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        // Add content controller
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "youtubePlayer")
        configuration.userContentController = contentController
        
        // Create and configure WebView
        let webView = webViewStore.createWebView(with: configuration, coordinator: context.coordinator)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        // Load player
        loadYouTubePlayer(webView)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload if the video ID changes
        if context.coordinator.currentVideoID != videoID {
            context.coordinator.currentVideoID = videoID
            loadYouTubePlayer(webView)
        }
    }
    
    private func loadYouTubePlayer(_ webView: WKWebView) {
        let html = YouTubePlayerHTML.generateHTML(videoID: videoID, playerVars: playerVars)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com")!)
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: YouTubePlayerView
        var currentVideoID: String
        var lastKnownTime: TimeInterval = 0
        var lastKnownPlaybackRate: Double = 1.0
        var pendingSeek: TimeInterval?
        var isInitialLoad = true
        
        init(parent: YouTubePlayerView) {
            self.parent = parent
            self.currentVideoID = parent.videoID
            super.init()
        }
        
        // MARK: - WKNavigationDelegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Logger.log("WebView finished loading", level: .debug)
        }
        
        // MARK: - WKScriptMessageHandler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let messageString = message.body as? String,
                  let data = messageString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let event = json["event"] as? String else {
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                switch event {
                case "ready":
                    self?.handleReadyEvent(json)
                case "stateChange":
                    self?.handleStateChangeEvent(json)
                case "timeUpdate":
                    self?.handleTimeUpdateEvent(json)
                case "playbackQualityChange":
                    self?.handleQualityChangeEvent(json)
                case "playbackRateChange":
                    self?.handleRateChangeEvent(json)
                case "error":
                    self?.handleErrorEvent(json)
                default:
                    break
                }
            }
        }
        
        // MARK: - Event Handlers
        private func handleReadyEvent(_ json: [String: Any]) {
            parent.isPlayerReady = true
        }
        
        private func handleStateChangeEvent(_ json: [String: Any]) {
            if let state = json["state"] as? Int {
                parent.playerState = state
            }
        }
        
        private func handleTimeUpdateEvent(_ json: [String: Any]) {
            if let time = json["time"] as? TimeInterval {
                lastKnownTime = time
                parent.currentVideoTime = time
            }
        }
        
        private func handleQualityChangeEvent(_ json: [String: Any]) {
            if let quality = json["quality"] as? String {
                parent.playbackQuality = quality
            }
        }
        
        private func handleRateChangeEvent(_ json: [String: Any]) {
            if let rate = json["rate"] as? Double {
                parent.playbackRate = rate
            }
        }
        
        private func handleErrorEvent(_ json: [String: Any]) {
            if let error = json["error"] as? String {
                parent.onError(error)
            }
        }
        
        // MARK: - Player Controls
        func play(_ webView: WKWebView) {
            evaluatePlayerCommand(webView, command: "playVideo()")
        }
        
        func pause(_ webView: WKWebView) {
            evaluatePlayerCommand(webView, command: "pauseVideo()")
        }
        
        func stop(_ webView: WKWebView) {
            evaluatePlayerCommand(webView, command: "stopVideo()")
        }
        
        func seek(_ webView: WKWebView, to seconds: TimeInterval) {
            evaluatePlayerCommand(webView, command: "seekTo(\(seconds), true)")
        }
        
        func setPlaybackRate(_ webView: WKWebView, rate: Double) {
            evaluatePlayerCommand(webView, command: "setPlaybackRate(\(rate))")
        }
        
        private func evaluatePlayerCommand(_ webView: WKWebView, command: String) {
            let javascript = "player.\(command);"
            webView.evaluateJavaScript(javascript) { [weak self] result, error in
                if let error = error {
                    self?.parent.onError("Error executing \(command): \(error.localizedDescription)")
                }
            }
        }
    }
}
