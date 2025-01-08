import SwiftUI
import WebKit
import os.log

struct TimelineCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var movieDatabase: MovieDatabase
    @StateObject private var webViewStore = WebViewStore()
    @State private var currentVideoTime: TimeInterval = 0
    @State private var isPlayerReady = false
    @State private var playerState = 0
    @State private var playbackQuality = "default"
    @State private var playbackRate = 1.0
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isFullscreen = false
    @State private var pendingSeek: TimeInterval?
    @State private var showTimeControls = false
    @State private var orientation = UIDevice.current.orientation
    @State private var youtubeView: YouTubePlayerView?
    @State private var showingCamera = false
    @State private var capturedNumbers: [Int]?
    @State private var recognizedTimeline: String?
    @State private var timelineError: String?
    @State private var captureTimestamp: Date?
    @State private var displayTimestamp: Date?
    @State private var totalDelay: TimeInterval?
    @State private var isUpdatingTime = false
    @State private var isLandscape = false
    @State private var captureStartTime: TimeInterval = 0
    @State private var processingTimer: Timer?
    @State private var lastKnownTime: TimeInterval = 0
    
    private let movieId: UUID
    private let originalMovie: Movie
    private let updateInterval: TimeInterval = 0.1 // 100ms update interval
    private let minSeekStep: TimeInterval = 0.1
    private let youtubeStartLatency: TimeInterval = 0.5 // 500ms YouTube player start latency
    private let networkLatency: TimeInterval = 0.1 // 100ms network latency
    
    // Computed property to get video ID from movie source
    private var videoID: String? {
        guard let posterURL = originalMovie.posterImage else {
            Logger.log("No poster URL found", level: .error)
            return nil
        }
        
        guard let url = URL(string: posterURL) else {
            Logger.log("Invalid URL format: \(posterURL)", level: .error)
            return nil
        }
        
        guard YouTubeURLUtility.isYouTubeURL(url) else {
            Logger.log("Not a YouTube URL: \(url)", level: .error)
            return nil
        }
        
        guard let videoID = YouTubeURLUtility.getYouTubeVideoID(from: url) else {
            Logger.log("Could not extract video ID from URL: \(url)", level: .error)
            return nil
        }
        
        Logger.log("Successfully extracted video ID: \(videoID)", level: .debug)
        return videoID
    }
    
    init(movie: Movie) {
        self.movieId = movie.id
        self.originalMovie = movie
        enableScreenRotation()
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // YouTube Player
                if let videoID = videoID {
                    if let youtubePlayerView = youtubeView {
                        youtubePlayerView
                            .frame(height: geometry.size.width * 9/16)
                            .background(Color.black)
                    } else {
                        YouTubePlayerView(
                            videoID: videoID,
                            webViewStore: webViewStore,
                            currentVideoTime: $currentVideoTime,
                            isPlayerReady: $isPlayerReady,
                            playerState: $playerState,
                            playbackQuality: $playbackQuality,
                            playbackRate: $playbackRate,
                            playerVars: [
                                "playsinline": 1,
                                "controls": 1,
                                "rel": 0,
                                "fs": 1,
                                "modestbranding": 1,
                                "enablejsapi": 1
                            ]
                        ) { error in
                            errorMessage = error
                            showError = true
                        }
                        .frame(height: geometry.size.width * 9/16)
                        .background(Color.black)
                    }
                } else {
                    Text("Invalid YouTube URL")
                        .foregroundColor(.red)
                        .frame(height: geometry.size.width * 9/16)
                        .background(Color.black)
                }
                
                // Timeline and controls
                VStack {
                    // Movie Title
                    Text(originalMovie.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
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
                    
                    Spacer()
                }
                .padding()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .navigationBarItems(
            leading: closeButton
        )
        .onAppear {
            setupYouTubeView()
            setupOrientationChangeNotification()
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
            isUpdatingTime = false
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(movie: originalMovie) { numbers in
                handleCapturedNumbers(numbers)
            }
        }
        .onChange(of: capturedNumbers) { oldValue, newValue in
            if let numbers = newValue {
                handleCapturedNumbers(numbers)
            }
        }
    }
    
    // MARK: - UI Components
    
    private var closeButton: some View {
        Button(action: {
            dismiss()
        }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.gray)
                .imageScale(.large)
        }
    }
    
    private var captureButton: some View {
        Button(action: {
            Logger.log("Opening camera for movie: \(originalMovie.title)", level: .debug)
            // Start timing when capture button is pressed
            captureStartTime = CACurrentMediaTime()
            showingCamera = true
        }) {
            VStack {
                Image(systemName: "camera")
                    .font(.system(size: 24))
                Text("Capture Timeline")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
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
        VStack(spacing: 16) {
            // Current YouTube Time Display
            VStack(spacing: 4) {
                Text(formatVideoTime(currentVideoTime))
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.7))
                    )
            }
            
            // Time Control Buttons
            HStack(spacing: 24) {
                // Decrease Time Button
                TimeControlButton(
                    action: { seekRelativeTime(-1.0) },
                    symbol: "minus.circle.fill",
                    size: 44,
                    color: .white
                )
                
                // Fine Control Buttons
                VStack(spacing: 8) {
                    // Fine Increase Button (+0.1s)
                    TimeControlButton(
                        action: { seekRelativeTime(minSeekStep) },
                        symbol: "plus.circle",
                        size: 32,
                        color: .white,
                        label: "+0.1s"
                    )
                    
                    // Fine Decrease Button (-0.1s)
                    TimeControlButton(
                        action: { seekRelativeTime(-minSeekStep) },
                        symbol: "minus.circle",
                        size: 32,
                        color: .white,
                        label: "-0.1s"
                    )
                }
                
                // Increase Time Button
                TimeControlButton(
                    action: { seekRelativeTime(1.0) },
                    symbol: "plus.circle.fill",
                    size: 44,
                    color: .white
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.7))
        )
        .onChange(of: currentVideoTime) { oldValue, newValue in
            // Update UI when time changes
            if !isUpdatingTime {
                lastKnownTime = newValue
            }
        }
    }
    
    private func formatVideoTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%01d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
        }
    }
    
    private func seekRelativeTime(_ offset: TimeInterval) {
        let newTime = max(0, currentVideoTime + offset)
        seekToVideoTime(newTime)
    }
    
    private func seekToVideoTime(_ time: TimeInterval) {
        guard let webView = webViewStore.webView else { return }
        seekToTime(webView, time: time)
    }
    
    private func seekToTime(_ webView: WKWebView, time: TimeInterval) {
        Logger.log("Seeking to time: \(time)", level: .debug)
        lastKnownTime = time
        pendingSeek = time
        
        let javascript = """
            if (window.seekVideo) {
                window.seekVideo(\(time));
            } else {
                if (window.player && typeof window.player.seekTo === 'function') {
                    window.player.seekTo(\(time), true);
                } else {
                    console.error('Player or seekTo not available');
                }
            }
        """
        
        webView.evaluateJavaScript(javascript) { result, error in
            if let error = error {
                Logger.log("Error seeking video: \(error.localizedDescription)", level: .error)
                handleSeekError(error)
            }
        }
    }
    
    private func handleSeekError(_ error: Error) {
        // Retry seek after a short delay if player might not be ready
        if pendingSeek != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard let webView = webViewStore.webView else { return }
                if let time = pendingSeek {
                    seekToTime(webView, time: time)
                }
            }
        }
        
        // Show error alert
        errorMessage = "Error seeking video: \(error.localizedDescription)"
        showError = true
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
        // Get current time when we're ready to play
        displayTimestamp = Date()
        
        // Calculate the delay between capture and playback readiness
        if let captureTime = captureTimestamp {
            // Calculate processing delay (time between capture and now)
            let processingDelay = displayTimestamp?.timeIntervalSince(captureTime) ?? 0
            
            // Add YouTube player initialization delay (empirically measured)
            let youtubeDelay: TimeInterval = 0.5 // 500ms for player to start playing
            
            // Total delay is processing time plus YouTube startup time
            let totalDelay = processingDelay + youtubeDelay
            
            // Round to nearest 0.1 second since that's our seeking precision
            let roundedDelay = round(totalDelay * 10) / 10
            self.totalDelay = roundedDelay
            
            Logger.log("""
                Synchronization delay breakdown:
                - Time shown in external video: \(originalSeconds)s
                - Processing delay: \(String(format: "%.1f", processingDelay))s
                - YouTube startup delay: \(String(format: "%.1f", youtubeDelay))s
                - Total delay: \(String(format: "%.1f", roundedDelay))s
                - Target playback time: \(originalSeconds + Int(ceil(roundedDelay)))s
                """, level: .debug)
            
            // Add the delay to the captured time to sync with external video
            let targetSeconds = originalSeconds + Int(ceil(roundedDelay))
            seekToVideoTime(TimeInterval(targetSeconds))
        } else {
            Logger.log("No capture timestamp available", level: .error)
            timelineError = "Could not calculate synchronization delay"
        }
    }
    
    // MARK: - Orientation Handling
    
    private func setupOrientationChangeNotification() {
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [self] _ in
            let newOrientation = UIDevice.current.orientation
            handleOrientationChange(newOrientation)
        }
    }
    
    private func handleOrientationChange(_ newOrientation: UIDeviceOrientation) {
        // Update orientation state
        orientation = newOrientation
        isLandscape = newOrientation.isLandscape
        
        // Store current time before orientation change
        let currentTime = currentVideoTime
        
        // Reset player view for new orientation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            setupYouTubeView()
            
            // Restore time after player is ready
            if isPlayerReady {
                seekToVideoTime(currentTime)
            } else {
                // Store the time to seek when player becomes ready
                pendingSeek = currentTime
            }
            
            // Ensure time updates continue
            setupYouTubeTimeUpdates()
        }
    }
    
    private func setupYouTubeTimeUpdates() {
        guard let webView = webViewStore.webView else { return }
        
        // Clear any existing timers
        processingTimer?.invalidate()
        processingTimer = nil
        
        let javascript = """
            function updateTime() {
                if (player && player.getCurrentTime) {
                    var currentTime = player.getCurrentTime();
                    window.webkit.messageHandlers.youtubePlayer.postMessage(JSON.stringify({
                        'event': 'timeUpdate',
                        'time': currentTime
                    }));
                }
                requestAnimationFrame(updateTime);
            }
            updateTime();
        """
        
        webView.evaluateJavaScript(javascript) { result, error in
            if let error = error {
                Logger.log("Error setting up time updates: \(error.localizedDescription)", level: .error)
            }
        }
        
        // Start a new timer for continuous updates
        processingTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            updateCurrentTime()
        }
    }
    
    private func updateCurrentTime() {
        guard let webView = webViewStore.webView else { return }
        
        let javascript = """
            if (player && player.getCurrentTime) {
                player.getCurrentTime();
            } else {
                -1;
            }
        """
        
        webView.evaluateJavaScript(javascript) { result, error in
            if let time = result as? TimeInterval, time >= 0 {
                DispatchQueue.main.async {
                    if !isUpdatingTime {
                        currentVideoTime = time
                        lastKnownTime = time
                    }
                }
            }
        }
    }
    
    // MARK: - Other
    
    private func saveTimeline() {
        guard let timeline = recognizedTimeline else {
            timelineError = "No timeline to save"
            return
        }
        
        // Here you can implement the logic to save the timeline
        Logger.log("Saving timeline: \(timeline)", level: .debug)
        
        // Dismiss the view after saving
        dismiss()
    }
    
    private func enableScreenRotation() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS()
            geometryPreferences.interfaceOrientations = .all
            windowScene.requestGeometryUpdate(geometryPreferences)
            windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
    
    private func setupYouTubeView() {
        if youtubeView == nil,
           let videoID = videoID {
            
            DispatchQueue.main.async {
                youtubeView = YouTubePlayerView(
                    videoID: videoID,
                    webViewStore: webViewStore,
                    currentVideoTime: $currentVideoTime,
                    isPlayerReady: $isPlayerReady,
                    playerState: $playerState,
                    playbackQuality: $playbackQuality,
                    playbackRate: $playbackRate,
                    playerVars: [
                        "playsinline": 1,
                        "controls": 1,
                        "rel": 0,
                        "fs": 1,
                        "modestbranding": 1,
                        "enablejsapi": 1
                    ]
                ) { error in
                    errorMessage = error
                    showError = true
                }
            }
        }
    }
    
    private func onPlayerReady() {
        setupYouTubeTimeUpdates()
        
        // Start with time controls visible
        showTimeControls = true
        
        // Initialize the current time
        updateCurrentTime()
    }
    
    private func onPlayerStateChange(_ state: Int) {
        playerState = state
        
        // YouTube Player States:
        // -1: Unstarted
        // 0: Ended
        // 1: Playing
        // 2: Paused
        // 3: Buffering
        // 5: Video cued
        
        switch state {
        case 1: // Playing
            if let pendingTime = pendingSeek {
                seekToVideoTime(pendingTime)
                self.pendingSeek = nil
            }
        case -1, 5: // Unstarted or cued
            setupYouTubeTimeUpdates()
        default:
            break
        }
    }
}

// MARK: - Orientation Helpers
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}

struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

struct TimeControlButton: View {
    let action: () -> Void
    let symbol: String
    let size: CGFloat
    let color: Color
    var label: String? = nil
    
    @State private var isLongPressing = false
    @State private var timer: Timer? = nil
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .resizable()
                    .frame(width: size, height: size)
                    .foregroundColor(color)
                
                if let label = label {
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(TimeControlButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    isLongPressing = true
                    startRepeatingAction()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    isLongPressing = false
                    stopRepeatingAction()
                }
        )
    }
    
    private func startRepeatingAction() {
        // Initial delay before rapid repeating
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard isLongPressing else { return }
            
            // Start the timer for continuous updates
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                guard isLongPressing else {
                    stopRepeatingAction()
                    return
                }
                action()
            }
        }
    }
    
    private func stopRepeatingAction() {
        timer?.invalidate()
        timer = nil
    }
}

struct TimeControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
