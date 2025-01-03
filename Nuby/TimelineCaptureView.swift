import SwiftUI
import WebKit
import os.log

struct TimelineCaptureView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var movieDatabase: MovieDatabase
    @State private var showingCamera = false
    @State private var capturedNumbers: [Int]?
    @State private var recognizedTimeline: String?
    @State private var timelineError: String?
    @State private var captureTimestamp: Date?
    @State private var displayTimestamp: Date?
    @State private var totalDelay: TimeInterval?
    @State private var webViewStore = WebViewStore()
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLandscape = false
    
    private var movie: Movie {
        movieDatabase.movies.first { $0.id == movieId } ?? originalMovie
    }
    
    private let movieId: UUID
    private let originalMovie: Movie
    
    init(movie: Movie) {
        self.movieId = movie.id
        self.originalMovie = movie
        enableScreenRotation()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    if !isLandscape {
                        Text(movie.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    
                    if let posterImage = movie.posterImage, let url = URL(string: posterImage) {
                        if !isLandscape {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Movie Link:")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text(url.absoluteString)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .padding(.horizontal)
                        }
                        
                        if Self.isYouTubeURL(url) {
                            YouTubePlayerView(url: url, webViewStore: webViewStore, isLandscape: $isLandscape) { error in
                                errorMessage = error
                                showError = true
                            }
                            .frame(
                                width: isLandscape ? UIScreen.main.bounds.width : geometry.size.width,
                                height: isLandscape ? UIScreen.main.bounds.height : min(geometry.size.width * 9/16, 300)
                            )
                            .cornerRadius(isLandscape ? 0 : 10)
                            .padding(.horizontal, isLandscape ? 0 : 16)
                            .edgesIgnoringSafeArea(isLandscape ? .all : [])
                        }
                    }
                    
                    if !isLandscape {
                        captureButton
                        
                        if let timeline = recognizedTimeline {
                            capturedTimeView(timeline: timeline)
                        }
                        
                        if let error = timelineError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.callout)
                                .padding()
                        }
                        
                        if recognizedTimeline != nil {
                            saveTimelineButton
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(movie: movie) { numbers in
                    handleCapturedNumbers(numbers)
                }
            }
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Video Error"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onAppear {
            setupOrientationChangeNotification()
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    private var captureButton: some View {
        Button(action: {
            Logger.log("Opening camera for movie: \(movie.title)", level: .debug)
            showingCamera = true
        }) {
            HStack {
                Image(systemName: "camera")
                Text("Capture Timeline")
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private func capturedTimeView(timeline: String) -> some View {
        VStack(spacing: 8) {
            Text("Captured Time")
                .font(.headline)
                .padding(.top)
            
            Text(timeline)
                .font(.body)
            
            if let delay = totalDelay {
                Text("Processing Delay: \(String(format: "%.2f", delay)) seconds")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var saveTimelineButton: some View {
        Button(action: saveTimeline) {
            Text("Save Timeline")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private func handleCapturedNumbers(_ numbers: [Int]) {
        Logger.log("Processing captured numbers: \(numbers)", level: .debug)
        capturedNumbers = numbers
        captureTimestamp = Date()
        processTimeline(numbers: numbers)
    }
    
    private func processTimeline(numbers: [Int]) {
        recognizedTimeline = formatTime(numbers: numbers)
        displayTimestamp = Date()
        
        if let captureTime = captureTimestamp {
            totalDelay = displayTimestamp?.timeIntervalSince(captureTime)
            Logger.log("Capture to display delay: \(totalDelay ?? 0) seconds", level: .debug)
            
            let capturedSeconds = (numbers[0] * 60) + numbers[1]
            let totalSeconds = Double(capturedSeconds) + (totalDelay ?? 0.0)
            
            if let url = URL(string: movie.posterImage ?? ""), Self.isYouTubeURL(url) {
                webViewStore.seek(to: totalSeconds)
            }
        }
        
        timelineError = nil
    }
    
    private func saveTimeline() {
        Logger.log("Attempting to save timeline for movie: \(movie.title)", level: .debug)
        
        guard let numbers = capturedNumbers, validateCapturedTime(numbers) else {
            Logger.log("Cannot save timeline: invalid captured time", level: .warning)
            return
        }
        
        let seconds = numbers[0] * 3600 + numbers[1] * 60
        
        let updatedMovie = Movie(
            id: movie.id,
            title: movie.title,
            cinema: movie.cinema,
            source: movie.source,
            posterImage: movie.posterImage,
            releaseDate: movie.releaseDate
        )
        
        movieDatabase.updateMovie(updatedMovie)
        Logger.log("Successfully saved timeline. New timestamp: \(formatTime(numbers: numbers))", level: .info)
        
        resetState()
    }
    
    private func resetState() {
        capturedNumbers = nil
        recognizedTimeline = nil
        timelineError = nil
        showingCamera = false
    }
    
    private func enableScreenRotation() {
        UIDevice.current.setValue(UIDeviceOrientation.unknown.rawValue, forKey: "orientation")
        UIViewController.attemptRotationToDeviceOrientation()
    }
    
    private func setupOrientationChangeNotification() {
        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { _ in
            isLandscape = UIDevice.current.orientation.isLandscape
        }
    }
    
    internal static func isYouTubeURL(_ url: URL) -> Bool {
        let host = url.host ?? ""
        return host.contains("youtube.com") || host.contains("youtu.be")
    }
    
    internal static func getYouTubeVideoID(from url: URL) -> String? {
        if url.host?.contains("youtu.be") == true {
            return url.lastPathComponent
        } else if url.host?.contains("youtube.com") == true {
            if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
                return queryItems.first(where: { $0.name == "v" })?.value
            }
        }
        return nil
    }
    
    internal static func getYouTubeEmbedURL(from url: URL) -> URL? {
        guard let videoID = getYouTubeVideoID(from: url) else { return nil }
        let embedURLString = "https://www.youtube.com/embed/\(videoID)?enablejsapi=1&playsinline=1&controls=1&rel=0&modestbranding=1&origin=\(Bundle.main.bundleIdentifier ?? "app")"
        return URL(string: embedURLString)
    }
    
    private func formatTime(numbers: [Int]) -> String {
        guard numbers.count >= 2 else { return "00:00" }
        return String(format: "%02d:%02d", numbers[0], numbers[1])
    }
    
    private func validateCapturedTime(_ numbers: [Int]) -> Bool {
        Logger.log("Validating captured time: \(numbers)", level: .debug)
        
        guard numbers.count >= 2 else {
            Logger.log("Invalid time format: insufficient numbers", level: .warning)
            timelineError = "Invalid time format"
            return false
        }
        
        let hours = numbers[0]
        let minutes = numbers[1]
        
        guard hours >= 0 && hours < 24 && minutes >= 0 && minutes < 60 else {
            Logger.log("Invalid time values - Hours: \(hours), Minutes: \(minutes)", level: .warning)
            timelineError = "Invalid time values"
            return false
        }
        
        Logger.log("Time validation successful", level: .debug)
        return true
    }
}

class WebViewStore: ObservableObject {
    weak var webView: WKWebView?
    
    func seek(to seconds: Double) {
        let javascript = """
        player.seekTo(\(seconds), true);
        """
        webView?.evaluateJavaScript(javascript)
    }
}

struct YouTubePlayerView: UIViewRepresentable {
    let url: URL
    @ObservedObject var webViewStore: WebViewStore
    @Binding var isLandscape: Bool
    let onError: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = preferences
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "videoPlayer")
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.allowsBackForwardNavigationGestures = false
        webViewStore.webView = webView
        
        if let videoID = TimelineCaptureView.getYouTubeVideoID(from: url) {
            Logger.log("Loading YouTube video ID: \(videoID)", level: .debug)
            
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <style>
                    body { 
                        margin: 0; 
                        background-color: black; 
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        height: 100vh;
                        width: 100vw;
                        overflow: hidden;
                    }
                    #player-container {
                        position: relative;
                        width: 100%;
                        height: 100%;
                    }
                    #player {
                        position: absolute;
                        top: 0;
                        left: 0;
                        width: 100%;
                        height: 100%;
                    }
                </style>
            </head>
            <body>
                <div id="player-container">
                    <div id="player"></div>
                </div>
                <script src="https://www.youtube.com/iframe_api"></script>
                <script>
                    var player;
                    
                    function onYouTubeIframeAPIReady() {
                        player = new YT.Player('player', {
                            videoId: '\(videoID)',
                            playerVars: {
                                'playsinline': 1,
                                'controls': 1,
                                'autoplay': 1,
                                'enablejsapi': 1,
                                'origin': window.location.origin,
                                'fs': 1,
                                'rel': 0,
                                'showinfo': 0,
                                'modestbranding': 1
                            },
                            events: {
                                'onReady': onPlayerReady,
                                'onError': onPlayerError,
                                'onStateChange': onPlayerStateChange
                            }
                        });
                    }
                    
                    function onPlayerReady(event) {
                        window.webkit.messageHandlers.videoPlayer.postMessage("ready");
                        event.target.playVideo();
                        
                        // Handle orientation changes
                        screen.orientation.addEventListener('change', function() {
                            updatePlayerSize();
                        });
                    }
                    
                    function updatePlayerSize() {
                        var isLandscape = screen.orientation.type.includes('landscape');
                        window.webkit.messageHandlers.videoPlayer.postMessage(isLandscape ? "landscape" : "portrait");
                    }
                    
                    function onPlayerError(event) {
                        var errorMessage = "";
                        switch(event.data) {
                            case 2:
                                errorMessage = "Invalid video ID";
                                break;
                            case 5:
                                errorMessage = "HTML5 player error";
                                break;
                            case 100:
                                errorMessage = "Video not found";
                                break;
                            case 101:
                            case 150:
                                errorMessage = "Video cannot be played in embedded player";
                                break;
                            default:
                                errorMessage = "Unknown error: " + event.data;
                        }
                        window.webkit.messageHandlers.videoPlayer.postMessage("error:" + errorMessage);
                    }
                    
                    function onPlayerStateChange(event) {
                        window.webkit.messageHandlers.videoPlayer.postMessage("state:" + event.data);
                    }
                </script>
            </body>
            </html>
            """
            
            webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
        } else {
            onError("Invalid YouTube URL")
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: YouTubePlayerView
        
        init(_ parent: YouTubePlayerView) {
            self.parent = parent
            super.init()
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let messageString = message.body as? String else { return }
            
            if messageString.starts(with: "error:") {
                let error = String(messageString.dropFirst(6))
                Logger.log("YouTube player error: \(error)", level: .error)
                parent.onError(error)
            } else if messageString == "landscape" {
                DispatchQueue.main.async {
                    self.parent.isLandscape = true
                }
            } else if messageString == "portrait" {
                DispatchQueue.main.async {
                    self.parent.isLandscape = false
                }
            } else {
                Logger.log("YouTube player message: \(messageString)", level: .debug)
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Logger.log("YouTube player loaded", level: .debug)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Logger.log("YouTube player error: \(error.localizedDescription)", level: .error)
            parent.onError(error.localizedDescription)
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                if let url = navigationAction.request.url {
                    UIApplication.shared.open(url)
                }
            }
            return nil
        }
    }
}
