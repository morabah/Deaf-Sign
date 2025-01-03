import SwiftUI
import Combine
import os.log

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
    @ObservedObject var movieManager: MovieManager
    
    @State private var isEditing = false
    @State private var debounceTimer: Timer?
    
    var body: some View {
        HStack {
            // Search Icon and Text Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
                
                TextField("Search movies...", text: $text, onEditingChanged: { editing in
                    isEditing = editing
                    if !editing && text.isEmpty {
                        movieManager.searchMovies(query: "")
                    }
                })
                .onChange(of: text) { newValue in
                    debounceSearch(newValue)
                }
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.vertical, 8)
                
                // Clear Button
                if !text.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 8)
                    }
                    .transition(.opacity)
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .animation(.easeInOut, value: text.isEmpty)
            
            // Cancel Button
            if isEditing {
                Button("Cancel") {
                    clearSearch()
                    isEditing = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .transition(.move(edge: .trailing))
                .animation(.easeInOut, value: isEditing)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    /// Debounces the search query to reduce unnecessary API calls
    private func debounceSearch(_ query: String) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            Logger.log("SearchBar - Performing search for: \(query)", level: .debug)
            movieManager.searchMovies(query: query)
        }
    }
    
    /// Clears the search text and resets the search results
    private func clearSearch() {
        text = ""
        movieManager.searchMovies(query: "")
        Logger.log("SearchBar - Search cleared", level: .debug)
    }
}

// MARK: - Search Error Types

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
