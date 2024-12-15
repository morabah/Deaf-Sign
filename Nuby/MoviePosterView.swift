import SwiftUI
import Kingfisher

struct MoviePosterView: View {
    /// The movie data to be displayed
    let movie: Movie
    
    /// Tracks whether image loading has failed
    @State private var loadFailed: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            if let posterImage = movie.posterImage, let url = URL(string: posterImage), !loadFailed {
                KFImage(url)
                    .placeholder {
                        ProgressView()
                            .frame(width: 150, height: 225)
                    }
                    .onFailure { _ in
                        loadFailed = true // Update state when loading fails
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 150, height: 225)
                    .clipped()
                    .cornerRadius(8)
            } else {
                // Fallback for missing or failed images
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 225)
                    .foregroundColor(.gray)
            }
            Text(movie.title)
                .font(.caption)
                .lineLimit(2)
                .frame(width: 150)
                .foregroundColor(.primary)
        }
    }
}
/// Preview for MoviePosterView to aid in design and development
#Preview {
    // Create a sample movie for preview purposes
    MoviePosterView(movie: Movie(
        id: UUID(),
        title: "Sample Movie",
        cinema: CinemaInformation(id: UUID(), name: "Sample Cinema", location: "Sample Location"),
        source: .cinema,
        posterImage: nil,
        releaseDate: nil
    ))
}
