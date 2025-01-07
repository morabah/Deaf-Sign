import SwiftUI
import WebKit
import os.log

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    @ObservedObject var webViewStore: WebViewStore
    @Binding var currentVideoTime: TimeInterval
    @Binding var isPlayerReady: Bool
    let onError: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
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
    }
    
    private func loadYouTubePlayer(_ webView: WKWebView) {
        let html = YouTubePlayerHTML.generateHTML(videoID: videoID)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com")!)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: YouTubePlayerView
        private var timeUpdateTimer: Timer?
        private var lastKnownTime: TimeInterval = 0
        private var pendingSeek: TimeInterval?
        var currentVideoID: String
        private var isInitialLoad = true
        
        init(_ parent: YouTubePlayerView) {
            self.parent = parent
            self.currentVideoID = parent.videoID
            super.init()
        }
        
        deinit {
            timeUpdateTimer?.invalidate()
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
            guard let messageString = message.body as? String else { return }
            
            if messageString.hasPrefix("time:") {
                let timeString = messageString.dropFirst(5)
                if let time = Double(timeString) {
                    DispatchQueue.main.async {
                        self.lastKnownTime = time
                        self.parent.currentVideoTime = time
                    }
                }
                return
            }
            
            guard let data = messageString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let event = json["event"] as? String else {
                Logger.log("Invalid message received from WebView", level: .error)
                return
            }
            
            switch event {
            case "ready":
                Logger.log("Player is ready", level: .debug)
                DispatchQueue.main.async {
                    self.parent.isPlayerReady = true
                    if let pendingTime = self.pendingSeek {
                        if let webView = self.parent.webViewStore.webView {
                            self.seekToTime(webView, time: pendingTime)
                        }
                        self.pendingSeek = nil
                    }
                }
                
            case "timeUpdate":
                if let time = json["time"] as? TimeInterval {
                    DispatchQueue.main.async {
                        self.lastKnownTime = time
                        self.parent.currentVideoTime = time
                    }
                }
                
            case "seeked":
                if let time = json["time"] as? TimeInterval {
                    Logger.log("Successfully seeked to time: \(time)", level: .debug)
                    DispatchQueue.main.async {
                        self.lastKnownTime = time
                        self.parent.currentVideoTime = time
                    }
                }
                
            case "error":
                if let error = json["error"] as? String {
                    Logger.log("Player error: \(error)", level: .error)
                    self.parent.onError(error)
                }
                
            default:
                Logger.log("Unknown event received: \(event)", level: .debug)
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
    }
}
