import SwiftUI
import WebKit

struct TimelineCaptureView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var movieDatabase: MovieDatabase
    let movie: Movie
    @State private var showingCamera = false
    @State private var capturedNumbers: [Int]?
    @State private var recognizedTimeline: String?
    @State private var timelineError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Movie Title
                Text(movie.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding()
                
                // Display the link text above the WebView
                if let posterImage = movie.posterImage, let url = URL(string: posterImage) {
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
                    
                    // WebView to display the movie link
                    WebView(url: url)
                        .frame(height: 300) // Set a fixed height for the WebView
                        .cornerRadius(10)
                        .padding(.horizontal)
                } else {
                    Text("No valid movie link available")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding()
                }
                
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
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                
                if let timeline = recognizedTimeline {
                    Text("Captured Time")
                        .font(.headline)
                        .padding(.top)
                    
                    Text(timeline)
                        .font(.body)
                }
                
                if let error = timelineError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.callout)
                        .padding()
                }
                
                if recognizedTimeline != nil {
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
            }
            .padding(.bottom, 20)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(movie: movie) { numbers in
                Logger.log("Processing captured numbers: \(numbers)", level: .debug)
                capturedNumbers = numbers
                recognizedTimeline = formatTime(numbers: numbers)
                timelineError = nil
            }
        }
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
    
    private func saveTimeline() {
        Logger.log("Attempting to save timeline for movie: \(movie.title)", level: .debug)
        
        guard let numbers = capturedNumbers, validateCapturedTime(numbers) else {
            Logger.log("Cannot save timeline: invalid captured time", level: .warning)
            return
        }
        
        let seconds = numbers[0] * 3600 + numbers[1] * 60
        
        // Create updated movie with the same properties
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
        
        // Reset state
        capturedNumbers = nil
        recognizedTimeline = nil
        timelineError = nil
        showingCamera = false
    }
    
    private func formatTime(numbers: [Int]) -> String {
        guard numbers.count >= 2 else { return "00:00" }
        return String(format: "%02d:%02d", numbers[0], numbers[1])
    }
}

// WebView to display the movie link
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
