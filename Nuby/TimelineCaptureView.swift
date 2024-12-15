import SwiftUI
import UIKit
import AVFoundation
import Vision
import AVKit
import WebKit

class TimelineCaptureViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var movie: Movie
    var onNumbersDetected: (([Int]) -> Void)?
    
    private var cameraHasOpened = false
    
    init(movie: Movie, onNumbersDetected: @escaping ([Int]) -> Void) {
        self.movie = movie
        self.onNumbersDetected = onNumbersDetected
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !cameraHasOpened {
            cameraHasOpened = true
            checkCameraPermissions()
        }
    }
    
    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            openCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if granted {
                        self.openCamera()
                    } else {
                        print("User denied camera access.")
                        self.dismiss(animated: true)
                    }
                }
            }
        case .denied, .restricted:
            print("Camera access not available.")
            self.dismiss(animated: true)
        @unknown default:
            print("Unknown camera permission status.")
            self.dismiss(animated: true)
        }
    }
    
    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("Camera not available on this device.")
            self.dismiss(animated: true)
            return
        }
        
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.cameraCaptureMode = .photo
        imagePicker.cameraDevice = .rear
        imagePicker.allowsEditing = false
        
        present(imagePicker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.originalImage] as? UIImage else {
            print("No image captured.")
            picker.dismiss(animated: true) {
                self.dismiss(animated: true)
            }
            return
        }
        
        picker.dismiss(animated: true) {
            self.analyzeImage(image)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        print("User canceled the image picker.")
        picker.dismiss(animated: true) {
            self.dismiss(animated: true)
        }
    }
    
    private func analyzeImage(_ image: UIImage) {
        print("Analyzing captured image for timeline data...")
        
        guard let ciImage = CIImage(image: image) else {
            print("Failed to create CIImage.")
            self.dismiss(animated: true)
            return
        }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Text recognition error: \(error)")
                DispatchQueue.main.async {
                    self.dismiss(animated: true)
                }
                return
            }
            
            guard let results = request.results as? [VNRecognizedTextObservation] else {
                print("No text observations found.")
                DispatchQueue.main.async {
                    self.dismiss(animated: true)
                }
                return
            }
            
            var fullText = ""
            for observation in results {
                for candidate in observation.topCandidates(3) {
                    fullText += candidate.string + "\n"
                }
            }

            let numbers = self.extractNumbersFromText(fullText)
            DispatchQueue.main.async {
                self.onNumbersDetected?(numbers)
                self.dismiss(animated: true)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0.1
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Text recognition failed: \(error)")
                DispatchQueue.main.async {
                    self.dismiss(animated: true)
                }
            }
        }
    }
    
    private func extractNumbersFromText(_ text: String) -> [Int] {
        print("Searching for time patterns...")
        
        let lines = text.components(separatedBy: .newlines)
        let patterns = [
            "\\b([0-1]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]\\b", // HH:MM:SS
            "\\b[0-5]?[0-9]:[0-5][0-9]\\b",                    // MM:SS
            "\\b\\d+[:\\s]\\d+[:\\s]\\d+\\b"                  // General pattern with spaces or colons
        ]
        
        for line in lines {
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, range: range) {
                    let timeString = (line as NSString).substring(with: match.range)
                    let components = timeString
                        .components(separatedBy: CharacterSet(charactersIn: ": "))
                        .filter { !$0.isEmpty }
                        .compactMap { Int($0) }
                    
                    if components.count == 2 {
                        // MM:SS
                        return [0] + components
                    } else if components.count == 3 {
                        // HH:MM:SS
                        return components
                    }
                }
            }
        }
        
        print("No valid time formats found.")
        return []
    }
}

struct TimelineCaptureView: View {
    @Environment(\.presentationMode) var presentationMode
    var movie: Movie
    
    @State private var capturedNumbers: [Int] = []
    @State private var showingCamera = false
    @State private var timelineError: String? = nil
    @State private var movieURL: String? = nil
    @State private var showingURL = false
    @State private var capturedTimeInSeconds: Int = 0
    
    // New properties for handling elapsed time and playback
    @State private var captureStartDate: Date? = nil
    @State private var totalPlayTime: Int = 0
    @State private var elapsedTime: Int = 0
    
    // Web view store for controlling YouTube playback
    @State private var webViewStore = WebViewStore()
    
    // Properties for showing current playback time and controlling video from UI
    @State private var currentPlaybackTime: Int = 0
    @State private var playbackTimeTimer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            headerView
            
            movieDetailsView
            
            if let url = movieURL {
                WebView(url: URL(string: url)!, startTime: totalPlayTime, webViewStore: webViewStore)
                    .frame(maxWidth: .infinity)
                    .frame(height: UIDevice.current.orientation.isLandscape ? UIScreen.main.bounds.height : 300)
                    .cornerRadius(10)
                    .padding(.top, 20)
                
                // Controls below the video
                HStack {
                    Button(action: {
                        adjustPlayback(by: -1)
                    }) {
                        Text("−")
                            .font(.system(size: 24, weight: .bold))
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    Text(formatTimeFromSeconds(currentPlaybackTime))
                        .font(.headline)
                        .frame(minWidth: 80)
                    
                    Spacer()
                    
                    Button(action: {
                        adjustPlayback(by: 1)
                    }) {
                        Text("+")
                            .font(.system(size: 24, weight: .bold))
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 40)
                .onAppear {
                    startPlaybackTimeUpdates()
                }
                .onDisappear {
                    stopPlaybackTimeUpdates()
                }
            }
            
            Text("Press the button below to capture the movie's timeline.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
            
            Spacer()
            
            captureButtonSection
            
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(movie: movie) { numbers in
                handleCapturedNumbers(numbers)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white) // Updated for dark mode
            }
            Spacer()
            Text("📦 Nuby")
                .font(.title)
                .fontWeight(.bold)
            Spacer()
            Color.clear
                .frame(width: 24, height: 24)
        }
        .padding()
    }
    
    private var movieDetailsView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(movie.title)
                .font(.headline)
            Text(movie.cinema.name)
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let releaseDate = movie.releaseDate {
                Text(releaseDate, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let posterImage = movie.posterImage {
                Button(action: {
                    self.movieURL = posterImage
                    self.showingURL = true
                    // If capturing started, record start time here to measure elapsed
                }) {
                    Text("Show Movie URL")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if showingURL, let url = movieURL {
                Text(url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal)
    }
    
    private var captureButtonSection: some View {
        VStack(spacing: 15) {
            Button(action: {
                // Start tracking elapsed time
                captureStartDate = Date()
                showingCamera = true
            }) {
                Text("Capture Timeline")
                    .font(.headline)
                    .foregroundColor(.white) // Updated for dark mode
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            
            if !capturedNumbers.isEmpty {
                Text("Captured Time: \(formatTime(numbers: capturedNumbers))")
                    .font(.headline)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            } else if let error = timelineError {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding(.bottom, 30)
    }
    
    private func handleCapturedNumbers(_ numbers: [Int]) {
        if !numbers.isEmpty {
            capturedNumbers = numbers
            timelineError = nil
            
            let hours = numbers[0]
            let minutes = numbers[1]
            let seconds = numbers[2]
            capturedTimeInSeconds = hours * 3600 + minutes * 60 + seconds
            
            // Calculate elapsed time since capture started
            if let start = captureStartDate {
                let elapsed = Int(Date().timeIntervalSince(start))
                elapsedTime = elapsed
            } else {
                elapsedTime = 0
            }
            
            // totalPlayTime = captured time + elapsed time
            totalPlayTime = capturedTimeInSeconds + elapsedTime
            
            // Reset elapsed time tracking after use
            captureStartDate = nil
            elapsedTime = 0
            
            if let posterImage = movie.posterImage {
                if movieURL == nil {
                    // First time playing
                    movieURL = posterImage
                    showingURL = true
                    // WebView will start from totalPlayTime automatically
                } else {
                    // Video already playing, seek to updated totalPlayTime
                    webViewStore.seekTo(seconds: totalPlayTime)
                }
            }
        } else {
            timelineError = "No timeline detected. Please try again."
        }
        showingCamera = false
    }
    
    private func adjustPlayback(by offset: Int) {
        // Fetch current time, add offset, and seek
        let newTime = currentPlaybackTime + offset
        webViewStore.seekTo(seconds: max(newTime, 0))
    }
    
    private func startPlaybackTimeUpdates() {
        // Poll current playback time every second
        playbackTimeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            webViewStore.getCurrentTime { time in
                if let t = time {
                    currentPlaybackTime = Int(t)
                }
            }
        }
    }
    
    private func stopPlaybackTimeUpdates() {
        playbackTimeTimer?.invalidate()
        playbackTimeTimer = nil
    }
    
    private func formatTime(numbers: [Int]) -> String {
        guard numbers.count >= 3 else { return "" }
        return String(format: "%02d:%02d:%02d", numbers[0], numbers[1], numbers[2])
    }
    
    private func formatTimeFromSeconds(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    let movie: Movie
    let onNumbersDetected: ([Int]) -> Void
    
    func makeUIViewController(context: Context) -> TimelineCaptureViewController {
        TimelineCaptureViewController(movie: movie, onNumbersDetected: onNumbersDetected)
    }
    
    func updateUIViewController(_ uiViewController: TimelineCaptureViewController, context: Context) { }
}

class WebViewStore: ObservableObject {
    weak var webView: WKWebView?
    
    func seekTo(seconds: Int) {
        let javascript = "player.seekTo(\(seconds), true); player.playVideo();"
        webView?.evaluateJavaScript(javascript, completionHandler: nil)
    }
    
    func getCurrentTime(completion: @escaping (Double?) -> Void) {
        let js = "player.getCurrentTime();"
        webView?.evaluateJavaScript(js) { result, error in
            if let time = result as? Double {
                completion(time)
            } else {
                completion(nil)
            }
        }
    }
}

class WebViewCoordinator: NSObject, WKNavigationDelegate {
    var parent: WebView
    
    init(_ parent: WebView) {
        self.parent = parent
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Enable inline playback and full-screen
        let javascript = """
            var video = document.querySelector('video');
            if (video) {
                video.webkitEnterFullscreen = function() {};
                video.webkitExitFullscreen = function() {};
                video.play();
            }
            document.querySelector('.ytp-fullscreen-button').addEventListener('click', function() {
                document.querySelector('video').webkitEnterFullscreen();
            });
        """
        webView.evaluateJavaScript(javascript, completionHandler: nil)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    let startTime: Int
    @ObservedObject var webViewStore: WebViewStore
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // Enable full-screen support
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        
        // Support rotation
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
        
        // Add JavaScript to handle rotation
        let javascript = """
            window.addEventListener('orientationchange', function() {
                var video = document.querySelector('video');
                if (video && window.orientation === 90 || window.orientation === -90) {
                    video.webkitEnterFullscreen();
                }
            });
        """
        webView.evaluateJavaScript(javascript, completionHandler: nil)
    }
}

// Preview
struct TimelineCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        TimelineCaptureView(movie: Movie(
            title: "Sample Movie",
            cinema: CinemaInformation(name: "Sample Cinema", location: "Sample Location"),
            source: .cinema
        ))
    }
}
