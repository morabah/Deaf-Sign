import SwiftUI
import os.log

/// MovieListItemView: A Dynamic and Flexible Movie List Item Component
///
/// Purpose:
/// Create a standardized, visually appealing, and interactive representation
/// of a movie item within various list contexts in the Nuby app.
///
/// Key Features:
/// - Consistent movie item design
/// - Source identification with icons
/// - Interactive list item with tap recognition
/// - Adaptive layout and styling
///
/// Design Philosophy:
/// - Minimalism
/// - Clear information hierarchy
/// - Visual consistency
///
/// Component Structure:
/// - Source icon (left)
/// - Movie details (center)
/// - Navigation indicator (right)
///
/// Interaction Capabilities:
/// - Tappable list item
/// - Visual feedback on interaction
/// - Logging of user interactions
///
/// Technical Details:
/// - Uses SwiftUI for responsive design
/// - Supports dynamic type and accessibility
/// - Lightweight and reusable component
///
/// Performance Considerations:
/// - Minimal computational overhead
/// - Efficient rendering
/// - Low memory footprint
///
/// - Version: 1.0.0
/// - Author: Nuby Development Team
/// - Copyright: 2024 Nuby App

/// A reusable view component representing a movie item in a list
/// Provides a consistent design for displaying movie information across different views
struct MovieListItemView: View {
    /// The movie data to be displayed
    let movie: Movie
    
    /// The system icon representing the source of the movie
    let sourceIcon: String
    
    /// The text description of the movie's source
    let sourceText: String
    
    var body: some View {
        // Horizontal stack for movie item layout
        HStack {
            // Source icon on the left side
            Image(systemName: sourceIcon)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(.gray)
            
            // Movie details in a vertical stack
            VStack(alignment: .leading, spacing: 4) {
                // Movie title
                Text(movie.title)
                    .font(.headline)
                
                // Movie source description
                Text(sourceText)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            // Spacer to push content to the left
            Spacer()
            
            // Chevron indicating navigability
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .onTapGesture {
            // Log when a movie list item is tapped
            os_log("Movie list item tapped: %{public}@", log: .default, type: .debug, movie.title)
        }
    }
}
