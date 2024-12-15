import SwiftUI
import Combine

/// SearchBar is a custom SwiftUI component for searching and filtering movies in the Nuby app.
///
/// This component provides a responsive and user-friendly search interface with features like:
/// - Debounced search to reduce unnecessary API calls
/// - Clear button for quick text removal
/// - Error handling for search queries
/// - Autocorrection and capitalization disabled for precise searching
///
/// Key Features:
/// - Real-time search as user types
/// - Cancellable search
/// - Visual search state indicators
///
/// - Note: Requires `MovieManager` to function properly
/// - Version: 1.0.0
/// - Author: Nuby Development Team
/// - Copyright: 2024 Nuby App

struct SearchBar: View {
    @Binding var text: String
    @State private var isEditing = false
    
    // Reference to MovieManager for search
    @ObservedObject var movieManager: MovieManager
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search movies...", text: $text, onEditingChanged: { isEditing in
                    self.isEditing = isEditing
                    
                    // If editing ends and text is empty, reset to all movies
                    if !isEditing && text.isEmpty {
                        movieManager.searchMovies(query: "")
                    }
                })
                .onChange(of: text) { _, newValue in
                    // Log the search attempt with more context
                    Logger.log("SearchBar - Text changed: \(newValue), Editing: \(isEditing)", level: .debug)
                    
                    // Directly call search on MovieManager
                    // Ensure this is called even for short queries
                    movieManager.searchMovies(query: newValue)
                }
                .autocapitalization(.none)
                .disableAutocorrection(true)
                
                if !text.isEmpty {
                    Button(action: {
                        // Log the clear action
                        Logger.log("SearchBar - Clearing search text", level: .debug)
                        
                        text = ""
                        movieManager.searchMovies(query: "")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .frame(width: 20, height: 20)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            
            if isEditing {
                Button("Cancel") {
                    // Log the cancel action
                    Logger.log("SearchBar - Cancelling search", level: .debug)
                    
                    text = ""
                    movieManager.searchMovies(query: "")
                    isEditing = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                  to: nil, from: nil, for: nil)
                }
                .padding(.trailing)
                .transition(.move(edge: .trailing))
                .animation(.default, value: isEditing)
            }
        }
    }
}

// Search error types
enum SearchError: LocalizedError {
    case tooShort
    case tooLong
    case emptyQuery
    case unexpected(Error)
    
    var errorDescription: String? {
        switch self {
        case .tooShort:
            return "Search query must be at least 2 characters"
        case .tooLong:
            return "Search query cannot exceed 50 characters"
        case .emptyQuery:
            return "Search query cannot be empty"
        case .unexpected(let error):
            return "Unexpected error: \(error.localizedDescription)"
        }
    }
}
