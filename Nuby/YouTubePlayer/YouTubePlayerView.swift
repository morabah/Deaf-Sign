import SwiftUI
import WebKit
import os.log
import Combine

// MARK: - YouTube Player State
class YouTubePlayerState: ObservableObject {
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isReady: Bool = false
    @Published var playerState: Int = -1
    @Published var playbackQuality: String = "default"
    @Published var playbackRate: Double = 1.0
    @Published var availableQualities: [String] = []
    @Published var availablePlaybackRates: [Double] = []
    @Published var error: String?
    @Published var videoData: [String: Any] = [:]
}

struct YouTubePlayerView: UIViewRepresentable {
    // MARK: - Properties
    let videoID: String
    @ObservedObject var webViewStore: WebViewStore
    @StateObject private var state = YouTubePlayerState()
    let onError: (String) -> Void
    
    // Configuration options
    var playerVars: [String: Any]
    var height: CGFloat = 300
    var width: CGFloat = .infinity
    
    // MARK: - Initialization
    init(videoID: String,
         webViewStore: WebViewStore,
         playerVars: [String: Any] = [:],
         height: CGFloat = 300,
         width: CGFloat = .infinity,
         onError: @escaping (String) -> Void) {
        self.videoID = videoID
        self.webViewStore = webViewStore
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
        contentController.add(context.coordinator, name: "playerReady")
        contentController.add(context.coordinator, name: "playerStateChange")
        contentController.add(context.coordinator, name: "playerError")
        contentController.add(context.coordinator, name: "playerConfig")
        contentController.add(context.coordinator, name: "qualityChange")
        contentController.add(context.coordinator, name: "rateChange")
        configuration.userContentController = contentController
        
        // Create and configure WebView using WebViewStore
        let webView = webViewStore.createWebView(with: configuration, coordinator: context.coordinator)
        
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
    
    // MARK: - Player Control Methods
    func play(_ webView: WKWebView) {
        webView.evaluateJavaScript("player.playVideo();")
    }
    
    func pause(_ webView: WKWebView) {
        webView.evaluateJavaScript("player.pauseVideo();")
    }
    
    func seekTo(_ webView: WKWebView, time: TimeInterval, allowSeekAhead: Bool = true) {
        webView.evaluateJavaScript("player.seekTo(\(time), \(allowSeekAhead));")
    }
    
    func setPlaybackRate(_ webView: WKWebView, rate: Double) {
        webView.evaluateJavaScript("player.setPlaybackRate(\(rate));")
    }
    
    func setPlaybackQuality(_ webView: WKWebView, quality: String) {
        webView.evaluateJavaScript("player.setPlaybackQuality('\(quality)');")
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: YouTubePlayerView
        var currentVideoID: String
        
        init(parent: YouTubePlayerView) {
            self.parent = parent
            self.currentVideoID = parent.videoID
            super.init()
        }
        
        // MARK: - WKScriptMessageHandler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                switch message.name {
                case "playerReady":
                    self.parent.state.isReady = true
                    
                case "playerStateChange":
                    if let state = body["state"] as? Int {
                        self.parent.state.playerState = state
                    }
                    if let currentTime = body["currentTime"] as? TimeInterval {
                        self.parent.state.currentTime = currentTime
                    }
                    if let duration = body["duration"] as? TimeInterval {
                        self.parent.state.duration = duration
                    }
                    if let videoData = body["videoData"] as? [String: Any] {
                        self.parent.state.videoData = videoData
                    }
                    
                case "playerError":
                    if let error = body["error"] as? Int {
                        let errorMessage: String
                        switch error {
                        case 2: errorMessage = "Invalid video ID"
                        case 5: errorMessage = "HTML5 player error"
                        case 100: errorMessage = "Video not found"
                        case 101, 150: errorMessage = "Video playback not allowed"
                        default: errorMessage = "Unknown error (\(error))"
                        }
                        self.parent.state.error = errorMessage
                        self.parent.onError(errorMessage)
                    }
                    
                case "playerConfig":
                    if let rates = body["playbackRates"] as? [Double] {
                        self.parent.state.availablePlaybackRates = rates
                    }
                    if let qualities = body["qualities"] as? [String] {
                        self.parent.state.availableQualities = qualities
                    }
                    
                case "qualityChange":
                    if let quality = body["quality"] as? String {
                        self.parent.state.playbackQuality = quality
                    }
                    if let qualities = body["availableQualities"] as? [String] {
                        self.parent.state.availableQualities = qualities
                    }
                    
                case "rateChange":
                    if let rate = body["rate"] as? Double {
                        self.parent.state.playbackRate = rate
                    }
                    if let rates = body["availableRates"] as? [Double] {
                        self.parent.state.availablePlaybackRates = rates
                    }
                    
                default:
                    break
                }
            }
        }
        
        // MARK: - WKNavigationDelegate
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let errorMessage = "Navigation failed: \(error.localizedDescription)"
            parent.state.error = errorMessage
            parent.onError(errorMessage)
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let errorMessage = "Navigation failed: \(error.localizedDescription)"
            parent.state.error = errorMessage
            parent.onError(errorMessage)
        }
    }
}
