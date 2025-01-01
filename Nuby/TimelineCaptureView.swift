import SwiftUI
import WebKit

struct TimelineCaptureView: View {
    @Environment(\.presentationMode) var presentationMode
    var movie: Movie
    
    @State private var capturedNumbers: [Int] = []
    @State private var showingCamera = false
    @State private var timelineError: String? = nil
    @State private var recognizedTimeline: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Movie Title
                Text(movie.title)
                    .font(.headline)
                    .padding(.top, 20)
                
                // Display the recognized timeline
                if !recognizedTimeline.isEmpty {
                    Text("Recognized Timeline: \(recognizedTimeline)")
                        .font(.headline)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
                
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
                
                // Capture Timeline Section
                Text("Press the button below to capture the movie's timeline.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                
                Button(action: {
                    showingCamera = true
                }) {
                    Text("Capture Timeline")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Captured Time Display
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
            .padding(.bottom, 20)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(movie: movie) { numbers in
                print("Recognized Numbers: \(numbers)") // Debugging
                capturedNumbers = numbers
                recognizedTimeline = formatTime(numbers: numbers)
                timelineError = nil
            }
        }
    }
    
    private func formatTime(numbers: [Int]) -> String {
        guard numbers.count >= 3 else { return "00:00:00" }
        return String(format: "%02d:%02d:%02d", numbers[0], numbers[1], numbers[2])
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
