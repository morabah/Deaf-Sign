import SwiftUI
import os.log

/// CinemaView: Cinema Movie Management Interface
///
/// Purpose:
/// Offers a clear way to browse, manage, and track cinema movies within the Nuby app.
///
/// Key Features:
/// - Cinema movie listing
/// - Movie selection
/// - Timeline capture access
/// - Settings navigation
///
/// Design Principles:
/// - Simple, clean interface
/// - Easy-to-understand navigation
/// - Responsive layout
/// - Accessible elements
///
/// Components:
/// - Settings button in a toolbar
/// - Filterable movie list
/// - Empty and loading states
///
/// Interaction:
/// - Tap a movie to select it
/// - Access timeline capture from a selected movie
/// - Open settings
///
/// Technical Details:
/// - Uses SwiftUI
/// - Integrates with MovieDatabase
/// - Filters movies based on search text
///
/// Performance:
/// - Loads movies lazily
/// - Filters on the client side
///
/// Error Handling and Integrity:
/// - If movie data is empty, shows a loading or empty state
/// - Logs actions for debugging
///
/// Version: 1.0.1
/// Author: Nuby Development Team
/// Copyright: 2024 Nuby App

struct CinemaView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var movieDatabase: MovieDatabase
    
    @State private var selectedMovie: Movie?
    @State private var showSettings = false
    @State private var cinemaMovies: [Movie] = []
    @State private var searchText = ""
    
    private var filteredMovies: [Movie] {
        if searchText.isEmpty {
            return cinemaMovies
        }
        return cinemaMovies.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if cinemaMovies.isEmpty {
                    ProgressView("Loading movies...")
                        .padding()
                } else if filteredMovies.isEmpty {
                    Text("No movies found")
                        .padding()
                } else {
                    List(filteredMovies) { movie in
                        MovieRow(movie: movie)
                            .onTapGesture {
                                selectedMovie = movie
                                os_log("Selected movie: %{public}@", log: .default, type: .debug, movie.title)
                            }
                    }
                    .searchable(text: $searchText)
                }
            }
            .navigationTitle("📦 Nuby Cinema")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                        os_log("Settings button pressed in CinemaView", log: .default, type: .debug)
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Settings")
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel("Open settings")
                        .accessibilityHint("Double tap to open app settings")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                        os_log("CinemaView dismissed", log: .default, type: .debug)
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Close")
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel("Close Cinema view")
                    }
                }
            }
            .onAppear {
                os_log("CinemaView appeared", log: .default, type: .debug)
                loadCinemaMovies()
            }
            .onChange(of: movieDatabase.movies) { _ in
                loadCinemaMovies()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $selectedMovie) { movie in
                TimelineCaptureView(movie: movie)
            }
        }
    }
    
    private func loadCinemaMovies() {
        let allMovies = movieDatabase.movies
        cinemaMovies = allMovies.filter { $0.source == .cinema }
        
        // Data integrity check
        if cinemaMovies.contains(where: { $0.title.isEmpty }) {
            os_log("Warning: Found a movie with an empty title.", log: .default, type: .error)
        }
        
        os_log("Cinema movies loaded. Count: %d", log: .default, type: .debug, cinemaMovies.count)
    }
}

#Preview {
    CinemaView()
}
