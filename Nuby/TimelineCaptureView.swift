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
    @State private var currentVideoTime: TimeInterval = 0
    @State private var isUpdatingTime = false
    private let updateInterval: TimeInterval = 0.1 // 100ms update interval
    private let initFraction: Double = 0.01 // 1 init = 0.01 seconds (100 inits = 1 second)
    
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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Movie Title
                        Text(movie.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        // URL Display and Player
                        if let url = URL(string: movie.posterImage ?? "") {
                            VStack(alignment: .leading) {
                                Text("Video URL:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text(url.absoluteString)
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .padding(.horizontal)
                            
                            if Self.isYouTubeURL(url) {
                                YouTubePlayerView(url: url, webViewStore: webViewStore, isLandscape: $isLandscape, currentTime: $currentVideoTime) { error in
                                    DispatchQueue.main.async {
                                        self.errorMessage = error
                                        self.showError = true
                                    }
                                }
                                .frame(
                                    width: isLandscape ? UIScreen.main.bounds.width : geometry.size.width,
                                    height: isLandscape ? UIScreen.main.bounds.height : min(geometry.size.width * 9/16, 300)
                                )
                            }
                        }
                        
                        // Timeline Section
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
                        
                        // Time Control View
                        timeControlView
                            .padding()
                        
                        // Capture Button
                        captureButton
                            .padding()
                    }
                    .padding(.vertical)
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(trailing: closeButton)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(movie: movie) { numbers in
                    handleCapturedNumbers(numbers)
                }
            }
            .onChange(of: capturedNumbers) { oldValue, newValue in
                if let numbers = newValue {
                    handleCapturedNumbers(numbers)
                }
            }
            .onAppear {
                setupOrientationChangeNotification()
                setupYouTubeTimeUpdates()
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self)
                isUpdatingTime = false
            }
        }
    }
    
    // MARK: - UI Components
    
    private var closeButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.gray)
                .imageScale(.large)
        }
    }
    
    private var captureButton: some View {
        Button(action: {
            Logger.log("Opening camera for movie: \(movie.title)", level: .debug)
            showingCamera = true
        }) {
            HStack {
                Image(systemName: "camera.fill")
                    .imageScale(.large)
                Text("Capture Timeline")
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .cornerRadius(10)
        }
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
    }
    
    private var timeControlView: some View {
        VStack(spacing: 8) {
            // Current YouTube Time Display
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.white)
                Text(formatVideoTime(currentVideoTime))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            
            // Time Control Buttons
            HStack(spacing: 20) {
                Button(action: { adjustTime(by: -initFraction) }) {
                    Image(systemName: "gobackward")
                        .imageScale(.large)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                
                Button(action: { adjustTime(by: initFraction) }) {
                    Image(systemName: "goforward")
                        .imageScale(.large)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
    }
    
    // MARK: - Timeline Handling
    
    private func handleCapturedNumbers(_ numbers: [Int]?) {
        guard let numbers = numbers else {
            timelineError = "No numbers captured"
            return
        }
        
        capturedNumbers = numbers
        captureTimestamp = Date()
        
        // Enhanced timeline recognition
        if numbers.count >= 4 {
            // Handle hours:minutes:seconds format (HH:MM:SS)
            let hours = numbers[0]
            let minutes = numbers[1]
            let seconds = numbers[2...3].reduce(0) { $0 * 10 + $1 }
            if hours < 24 && minutes < 60 && seconds < 60 {
                recognizedTimeline = "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
                let totalSeconds = (hours * 3600) + (minutes * 60) + seconds
                calculateDelayAndSeek(originalSeconds: totalSeconds)
            } else {
                timelineError = "Invalid time values"
            }
        } else if numbers.count >= 2 {
            // Handle minutes:seconds format (MM:SS)
            let minutes = numbers[0]
            let seconds = numbers[1]
            if minutes < 60 && seconds < 60 {
                recognizedTimeline = "\(minutes):\(String(format: "%02d", seconds))"
                let totalSeconds = (minutes * 60) + seconds
                calculateDelayAndSeek(originalSeconds: totalSeconds)
            } else {
                timelineError = "Invalid time values"
            }
        } else {
            timelineError = "Invalid timeline format"
        }
    }
    
    private func calculateDelayAndSeek(originalSeconds: Int) {
        // Calculate processing delay
        displayTimestamp = Date()
        var processingDelay: TimeInterval = 0
        
        if let captureTime = captureTimestamp {
            processingDelay = displayTimestamp?.timeIntervalSince(captureTime) ?? 0
        }
        
        // Ensure minimum delay of 1 second
        let adjustedDelay = max(processingDelay, 2.5)
        totalDelay = adjustedDelay
        
        // Add delay to the original time
        let adjustedSeconds = originalSeconds + Int(ceil(adjustedDelay))
        Logger.log("Original time: \(originalSeconds)s, Delay: \(adjustedDelay)s, Adjusted time: \(adjustedSeconds)s", level: .debug)
        
        // Seek to adjusted time
        seekToVideoTime(adjustedSeconds)
    }
    
    private func seekToVideoTime(_ seconds: Int) {
        guard let webView = webViewStore.webView else { return }
        
        let javascript = "window.seekToTime(\(seconds));"
        
        DispatchQueue.main.async {
            webView.evaluateJavaScript(javascript) { result, error in
                if let error = error {
                    Logger.log("Error seeking video: \(error.localizedDescription)", level: .error)
                    self.errorMessage = "Failed to seek video: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    private func saveTimeline() {
        guard let timeline = recognizedTimeline else {
            timelineError = "No timeline to save"
            return
        }
        
        // Here you can implement the logic to save the timeline
        Logger.log("Saving timeline: \(timeline)", level: .debug)
        
        // Dismiss the view after saving
        presentationMode.wrappedValue.dismiss()
    }
    
    private func enableScreenRotation() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS()
            geometryPreferences.interfaceOrientations = .all
            windowScene.requestGeometryUpdate(geometryPreferences)
            windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
    
    private func setupOrientationChangeNotification() {
        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { _ in
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                self.isLandscape = windowScene.interfaceOrientation.isLandscape
            }
        }
    }
    
    internal static func isYouTubeURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("youtube.com") || host.contains("youtu.be")
    }
    
    internal static func getYouTubeVideoID(from url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        
        if host.contains("youtu.be") {
            return url.lastPathComponent
        } else if host.contains("youtube.com") {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value,
                  !videoID.isEmpty else {
                return nil
            }
            return videoID
        }
        return nil
    }
    
    internal static func getYouTubeEmbedURL(from url: URL) -> URL? {
        guard let videoID = getYouTubeVideoID(from: url) else { return nil }
        let embedURLString = "https://www.youtube.com/embed/\(videoID)?enablejsapi=1&playsinline=1&controls=1&rel=0&modestbranding=1&origin=\(Bundle.main.bundleIdentifier ?? "app")"
        return URL(string: embedURLString)
    }
    
    internal static func validateAndFormatURL(_ urlString: String) -> URL? {
        var formattedString = urlString
        
        // If URL doesn't start with a protocol, add https://
        if !formattedString.lowercased().hasPrefix("http") {
            formattedString = "https://" + formattedString
        }
        
        // If URL starts with http://, replace with https://
        if formattedString.lowercased().hasPrefix("http://") {
            formattedString = "https://" + formattedString.dropFirst("http://".count)
        }
        
        // If URL doesn't have www. after https://, add it
        if formattedString.lowercased().hasPrefix("https://") && !formattedString.lowercased().hasPrefix("https://www.") {
            formattedString = formattedString.replacingOccurrences(of: "https://", with: "https://www.")
        }
        
        return URL(string: formattedString)
    }
    
    private func formatVideoTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        let inits = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, inits)
    }
    
    private func adjustTime(by amount: Double) {
        let newTime = max(0, currentVideoTime + amount)
        currentVideoTime = newTime
        seekToVideoTime(Int(newTime), inits: Int((newTime.truncatingRemainder(dividingBy: 1)) * 100))
    }
    
    private func setupYouTubeTimeUpdates() {
        guard let webView = webViewStore.webView else { return }
        
        let javascript = """
            function updateTime() {
                if (player && player.getCurrentTime) {
                    var currentTime = player.getCurrentTime();
                    window.webkit.messageHandlers.youtubePlayer.postMessage("time:" + currentTime);
                }
                requestAnimationFrame(updateTime);
            }
            updateTime();
        """
        
        webView.evaluateJavaScript(javascript)
    }
    
    private func seekToVideoTime(_ seconds: Int, inits: Int = 0) {
        guard let webView = webViewStore.webView else { return }
        
        let totalSeconds = Double(seconds) + Double(inits) / 100.0
        let javascript = """
            if (player && player.seekTo) {
                player.seekTo(\(totalSeconds), true);
                player.playVideo();
            }
        """
        
        webView.evaluateJavaScript(javascript) { result, error in
            if let error = error {
                Logger.log("Error seeking video: \(error.localizedDescription)", level: .error)
                self.errorMessage = "Failed to seek video: \(error.localizedDescription)"
                self.showError = true
            } else {
                Logger.log("Successfully seeked to \(totalSeconds) seconds", level: .debug)
            }
        }
    }
}

struct YouTubePlayerView: UIViewRepresentable {
    let url: URL
    @ObservedObject var webViewStore: WebViewStore
    @Binding var isLandscape: Bool
    @Binding var currentTime: TimeInterval
    let onError: (String) -> Void
    
    @State private var isPlayerReady = false
    @State private var pendingSeekTime: TimeInterval?
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: YouTubePlayerView
        private var currentOrientation: Bool?
        
        init(_ parent: YouTubePlayerView) {
            self.parent = parent
            super.init()
        }
        
        func shouldUpdateOrientation(_ isLandscape: Bool) -> Bool {
            guard currentOrientation != isLandscape else { return false }
            currentOrientation = isLandscape
            return true
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let messageString = message.body as? String,
                  let data = messageString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let event = json["event"] as? String else {
                return
            }
            
            DispatchQueue.main.async {
                switch event {
                case "ready":
                    Logger.log("YouTube player ready", level: .debug)
                    self.parent.isPlayerReady = true
                    if let pendingTime = self.parent.pendingSeekTime {
                        self.parent.seekToTime(pendingTime)
                        self.parent.pendingSeekTime = nil
                    }
                    
                case "timeUpdate":
                    if let time = json["time"] as? TimeInterval {
                        self.parent.currentTime = time
                    }
                    
                case "error":
                    if let error = json["error"] as? String {
                        Logger.log("YouTube player error: \(error)", level: .error)
                        self.parent.onError(error)
                    }
                    
                case "stateChange":
                    if let state = json["state"] as? Int {
                        switch state {
                        case -1: // unstarted
                            Logger.log("Player unstarted", level: .debug)
                            self.parent.isPlayerReady = false
                        case 0: // ended
                            Logger.log("Player ended", level: .debug)
                        case 1: // playing
                            Logger.log("Player playing", level: .debug)
                            self.parent.isPlayerReady = true
                        case 2: // paused
                            Logger.log("Player paused", level: .debug)
                        case 3: // buffering
                            Logger.log("Player buffering", level: .debug)
                        case 5: // video cued
                            Logger.log("Player video cued", level: .debug)
                            self.parent.isPlayerReady = true
                        default:
                            Logger.log("Unknown player state: \(state)", level: .debug)
                        }
                    }
                    
                case "seeked":
                    if let time = json["time"] as? TimeInterval {
                        Logger.log("Seeked to time: \(time)", level: .debug)
                        self.parent.currentTime = time
                    }
                    
                default:
                    Logger.log("Unknown event: \(event)", level: .debug)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Logger.log("WebView failed to load: \(error.localizedDescription)", level: .error)
            parent.onError(error.localizedDescription)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Logger.log("WebView navigation failed: \(error.localizedDescription)", level: .error)
            parent.onError(error.localizedDescription)
        }
    }
    
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
        contentController.add(context.coordinator, name: "youtubePlayer")
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        
        webViewStore.webView = webView
        
        if let videoID = TimelineCaptureView.getYouTubeVideoID(from: url) {
            Logger.log("Loading YouTube video ID: \(videoID)", level: .debug)
            
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <style>
                    body { margin: 0; background-color: transparent; }
                    .container { position: relative; padding-bottom: 56.25%; height: 0; overflow: hidden; }
                    #player { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div id="player"></div>
                </div>
                <script>
                    var tag = document.createElement('script');
                    tag.src = "https://www.youtube.com/iframe_api";
                    var firstScriptTag = document.getElementsByTagName('script')[0];
                    firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
                    
                    var player;
                    var timeUpdateInterval;
                    var isPlayerReady = false;
                    var seekQueue = [];
                    
                    function processSeekQueue() {
                        if (seekQueue.length > 0 && isPlayerReady) {
                            var seconds = seekQueue.shift();
                            performSeek(seconds);
                        }
                    }
                    
                    function performSeek(seconds) {
                        if (!player || !isPlayerReady) {
                            seekQueue.push(seconds);
                            return;
                        }
                        
                        try {
                            player.seekTo(seconds, true);
                            player.playVideo();
                            window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                                'event': 'seeked',
                                'time': seconds
                            }));
                        } catch (error) {
                            window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                                'event': 'error',
                                'error': 'Seek error: ' + error.message
                            }));
                        }
                    }
                    
                    window.seekToTime = function(seconds) {
                        if (isPlayerReady) {
                            performSeek(seconds);
                        } else {
                            seekQueue.push(seconds);
                            setTimeout(function() {
                                processSeekQueue();
                            }, 500);
                        }
                    }
                    
                    function onYouTubeIframeAPIReady() {
                        player = new YT.Player('player', {
                            videoId: '\(videoID)',
                            playerVars: {
                                'playsinline': 1,
                                'rel': 0,
                                'controls': 1,
                                'enablejsapi': 1,
                                'origin': window.location.origin
                            },
                            events: {
                                'onReady': onPlayerReady,
                                'onError': onPlayerError,
                                'onStateChange': onPlayerStateChange
                            }
                        });
                    }
                    
                    function startTimeUpdates() {
                        if (timeUpdateInterval) {
                            clearInterval(timeUpdateInterval);
                        }
                        timeUpdateInterval = setInterval(function() {
                            if (player && player.getCurrentTime && isPlayerReady) {
                                try {
                                    var currentTime = player.getCurrentTime();
                                    window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                                        'event': 'timeUpdate',
                                        'time': currentTime
                                    }));
                                } catch (error) {
                                    console.error('Error getting current time:', error);
                                }
                            }
                        }, 200);
                    }
                    
                    function stopTimeUpdates() {
                        if (timeUpdateInterval) {
                            clearInterval(timeUpdateInterval);
                            timeUpdateInterval = null;
                        }
                    }
                    
                    function onPlayerReady(event) {
                        isPlayerReady = true;
                        window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                            'event': 'ready'
                        }));
                        startTimeUpdates();
                        processSeekQueue();
                    }
                    
                    function onPlayerError(event) {
                        stopTimeUpdates();
                        isPlayerReady = false;
                        var errorMessage = '';
                        switch(event.data) {
                            case 2:
                                errorMessage = 'Invalid video ID';
                                break;
                            case 5:
                                errorMessage = 'HTML5 player error';
                                break;
                            case 100:
                                errorMessage = 'Video not found';
                                break;
                            case 101:
                            case 150:
                                errorMessage = 'Video not playable in embedded player';
                                break;
                            default:
                                errorMessage = 'Unknown error: ' + event.data;
                        }
                        window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                            'event': 'error',
                            'error': errorMessage
                        }));
                    }
                    
                    function onPlayerStateChange(event) {
                        var state = event.data;
                        if (state === YT.PlayerState.PLAYING) {
                            startTimeUpdates();
                        } else if (state === YT.PlayerState.PAUSED || state === YT.PlayerState.ENDED) {
                            stopTimeUpdates();
                        }
                        
                        window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                            'event': 'stateChange',
                            'state': state
                        }));
                    }
                    
                    window.onerror = function(message, source, lineno, colno, error) {
                        window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                            'event': 'error',
                            'error': 'JavaScript error: ' + message
                        }));
                        return false;
                    };
                </script>
            </body>
            </html>
            """
            
            webView.loadHTMLString(html, baseURL: url)
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.shouldUpdateOrientation(isLandscape) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                webView.setNeedsLayout()
            }
        }
    }
    
    func seekToTime(_ seconds: TimeInterval) {
        if isPlayerReady {
            webViewStore.webView?.evaluateJavaScript("window.seekToTime(\(seconds));", completionHandler: { (result, error) in
                if let error = error {
                    Logger.log("Error seeking video: \(error.localizedDescription)", level: .error)
                    onError("Failed to seek video: \(error.localizedDescription)")
                }
            })
        } else {
            pendingSeekTime = seconds
            Logger.log("Player not ready, queuing seek to \(seconds)", level: .debug)
        }
    }
}

class WebViewStore: ObservableObject {
    weak var webView: WKWebView?
}
