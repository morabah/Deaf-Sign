import SwiftUI
import os.log

/// A reusable view component for displaying movie items across different views in the Nuby app.
///
/// This view provides a consistent, minimalist design for movie items with standardized styling
/// and accessibility considerations.
struct SharedMovieItemView: View {
    /// The movie to be displayed
    let movie: Movie
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(movie.title)
                .font(.headline)
                .accessibilityLabel("Movie: \(movie.title)")
            
            // Optional: Add more movie details if desired
            Text(movie.cinema.name)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
        .onAppear {
            os_log("Movie item displayed: %{public}@", log: .default, type: .debug, movie.title)
        }
    }
}
