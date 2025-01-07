import SwiftUI
import WebKit
import os.log

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    @ObservedObject var webViewStore: WebViewStore
    @Binding var currentVideoTime: TimeInterval
    @Binding var isPlayerReady: Bool
    let onError: (String) -> Void
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: YouTubePlayerView
        
        init(_ parent: YouTubePlayerView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Logger.log("WebView finished loading", level: .debug)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Logger.log("WebView failed to load: \(error.localizedDescription)", level: .error)
            parent.onError("Failed to load video: \(error.localizedDescription)")
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let messageString = message.body as? String else { return }
            
            if messageString.hasPrefix("time:") {
                let timeString = messageString.dropFirst(5)
                if let time = Double(timeString) {
                    parent.currentVideoTime = time
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
                parent.isPlayerReady = true
                
            case "error":
                if let error = json["error"] as? String {
                    Logger.log("Player error: \(error)", level: .error)
                    parent.onError(error)
                }
                
            case "seeked":
                if let time = json["time"] as? TimeInterval {
                    Logger.log("Seeked to time: \(time)", level: .debug)
                    parent.currentVideoTime = time
                }
                
            default:
                Logger.log("Unknown event received: \(event)", level: .debug)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "youtubePlayer")
        configuration.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        webViewStore.webView = webView
        
        Logger.log("Loading YouTube video ID: \(videoID)", level: .debug)
        let html = YouTubePlayerHTML.generateHTML(videoID: videoID)
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com")!)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Handle any updates if needed
    }
}
