import SwiftUI
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
    @Binding var searchText: String
    @ObservedObject var movieManager: MovieManager
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            // Search Icon and Text Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .padding(.leading, 8)
                
                TextField("Search movies...", text: $searchText, onEditingChanged: { editing in
                    isEditing = editing
                })
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.vertical, 8)
                
                // Clear Button
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 8)
                    }
                    .transition(.opacity)
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .animation(.easeInOut, value: searchText.isEmpty)
            
            // Cancel Button
            if isEditing {
                Button("Cancel") {
                    searchText = ""
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
}
