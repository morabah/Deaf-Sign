import SwiftUI
import WebKit
import os.log

struct TimelineCaptureView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var movieDatabase: MovieDatabase
    @StateObject private var webViewStore = WebViewStore()
    @State private var currentVideoTime: TimeInterval = 0
    @State private var lastKnownTime: TimeInterval = 0
    @State private var isPlayerReady: Bool = false
    @State private var showTimeControls = false
    @State private var showError = false
    @State private var errorMessage = ""
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
    
    private let movieId: UUID
    private let originalMovie: Movie
    private let updateInterval: TimeInterval = 0.1 // 100ms update interval
    private let minSeekStep: Double = 0.1 // Minimum seek step (100ms)
    
    private var movie: Movie {
        movieDatabase.movies.first { $0.id == movieId } ?? originalMovie
    }
    
    init(movie: Movie) {
        self.movieId = movie.id
        self.originalMovie = movie
        enableScreenRotation()
    }
    
    var body: some View {
        Group {
            if orientation.isLandscape {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .onAppear {
            setupYouTubeView()
            setupOrientationChangeNotification()
            setupYouTubeTimeUpdates()
        }
        .onRotate { newOrientation in
            // Store the current time before orientation change
            lastKnownTime = currentVideoTime
            orientation = newOrientation
            
            // After orientation change, restore the time
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let webView = webViewStore.webView {
                    seekToTime(webView: webView, time: lastKnownTime)
                }
            }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarItems(trailing: closeButton)
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
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
            isUpdatingTime = false
        }
    }
    
    private var landscapeLayout: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // YouTube Player
            if let youtubePlayerView = youtubeView {
                youtubePlayerView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
            }
            
            // Controls Overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            showTimeControls.toggle()
                        }
                    }) {
                        Image(systemName: "clock.circle.fill")
                            .resizable()
                            .frame(width: 44, height: 44)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                            .padding()
                    }
                }
                Spacer()
                
                if showTimeControls {
                    timeControlView
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private var portraitLayout: some View {
        VStack {
            if let youtubePlayerView = youtubeView {
                youtubePlayerView
                    .frame(height: 300)
            }
            
            ScrollView {
                VStack(spacing: 20) {
                    // Movie Title
                    Text(movie.title)
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
        .navigationBarItems(
            leading: closeButton
        )
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
    }
    
    private func formatVideoTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%01d", hours, minutes, seconds, tenths)
        } else {
            return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
        }
    }
    
    private struct TimeControlButton: View {
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
    
    private struct TimeControlButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .opacity(configuration.isPressed ? 0.7 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        }
    }
    
    private func seekRelativeTime(_ offset: TimeInterval) {
        let newTime = max(0, currentVideoTime + offset)
        // Round to nearest 0.1 second for YouTube compatibility
        let roundedTime = round(newTime * 10) / 10
        seekToVideoTime(roundedTime)
    }
    
    private func seekToVideoTime(_ targetTime: TimeInterval) {
        guard let webView = webViewStore.webView else { return }
        
        let javascript = "window.seekVideo(\(targetTime));"
        
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
    
    private func seekToTime(webView: WKWebView, time: TimeInterval) {
        let javascript = "window.seekVideo(\(time));"
        webView.evaluateJavaScript(javascript) { result, error in
            if let error = error {
                Logger.log("Error seeking video: \(error.localizedDescription)", level: .error)
            }
        }
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
        seekToVideoTime(TimeInterval(adjustedSeconds))
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
    
    private func setupYouTubeView() {
        if youtubeView == nil,
           let url = URL(string: movie.posterImage ?? ""),
           Self.isYouTubeURL(url),
           let videoID = Self.getYouTubeVideoID(from: url) {
            
            DispatchQueue.main.async {
                youtubeView = YouTubePlayerView(
                    videoID: videoID,
                    webViewStore: webViewStore,
                    currentVideoTime: $currentVideoTime,
                    isPlayerReady: $isPlayerReady,
                    onError: { error in
                        errorMessage = error
                        showError = true
                    }
                )
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
