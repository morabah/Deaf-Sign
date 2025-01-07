import SwiftUI
import WebKit

class WebViewStore: ObservableObject {
    @Published private(set) var webView: WKWebView?
    private var configuration: WKWebViewConfiguration?
    
    func createWebView(with config: WKWebViewConfiguration, coordinator: WKScriptMessageHandler) -> WKWebView {
        if let existingWebView = webView {
            return existingWebView
        }
        
        // Store configuration for later use
        self.configuration = config
        
        // Configure the web view
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let userContentController = WKUserContentController()
        userContentController.add(coordinator, name: "youtubePlayer")
        config.userContentController = userContentController
        
        // Create new web view
        let newWebView = WKWebView(frame: .zero, configuration: config)
        newWebView.scrollView.isScrollEnabled = false
        newWebView.isOpaque = false
        newWebView.backgroundColor = .clear
        newWebView.scrollView.backgroundColor = .clear
        
        // Update state on main thread
        DispatchQueue.main.async { [weak self] in
            self?.webView = newWebView
        }
        
        return newWebView
    }
    
    func resetWebView(coordinator: WKScriptMessageHandler) {
        guard let config = configuration else { return }
        
        // Clean up old configuration
        config.userContentController.removeAllUserScripts()
        config.userContentController.removeScriptMessageHandler(forName: "youtubePlayer")
        
        // Add new message handler
        config.userContentController.add(coordinator, name: "youtubePlayer")
        
        // Create new WebView with the same configuration
        let newWebView = WKWebView(frame: .zero, configuration: config)
        newWebView.scrollView.isScrollEnabled = false
        newWebView.isOpaque = false
        newWebView.backgroundColor = .clear
        newWebView.scrollView.backgroundColor = .clear
        
        // Update state on main thread
        DispatchQueue.main.async { [weak self] in
            self?.webView = newWebView
        }
    }
}
