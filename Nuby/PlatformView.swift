
import SwiftUI
import os.log

/// PlatformView displays a list of platform-type movies in the Nuby app.
///
/// Features:
/// - Displays platform-based movies
/// - Allows filtering by search text
/// - Enables selecting a movie for timeline capture
/// - Provides access to settings
///
/// Technical Notes:
/// - Uses SwiftUI and data from MovieDatabase
/// - Filters movies client-side
/// - Shows loading and empty states
///
/// Version: 1.0.1
/// Author: Nuby Development Team
/// Copyright: 2024 Nuby App

struct PlatformView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var movieDatabase: MovieDatabase
    
    @State private var selectedMovie: Movie?
    @State private var showSettings = false
    @State private var platformMovies: [Movie] = []
    @State private var searchText = ""
    
    private var filteredMovies: [Movie] {
        if searchText.isEmpty {
            return platformMovies
        }
        return platformMovies.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if platformMovies.isEmpty {
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
            .navigationTitle("📦 Nuby Platform")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                        os_log("Settings button pressed in PlatformView", log: .default, type: .debug)
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
                        os_log("PlatformView dismissed", log: .default, type: .debug)
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Close")
                                .foregroundColor(.white)
                        }
                        .accessibilityLabel("Close Platform view")
                    }
                }
            }
            .onAppear {
                os_log("PlatformView appeared", log: .default, type: .debug)
                loadPlatformMovies()
            }
            .onChange(of: movieDatabase.movies, initial: true) { oldValue, newValue in
                loadPlatformMovies()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $selectedMovie) { movie in
                TimelineCaptureView(movie: movie)
            }
        }
    }
    
    private func loadPlatformMovies() {
        let allMovies = movieDatabase.movies
        platformMovies = allMovies.filter { $0.source == .platform }
        
        // Simple data integrity check
        if platformMovies.contains(where: { $0.title.isEmpty }) {
            os_log("Warning: Found a movie with an empty title.", log: .default, type: .error)
        }
        
        os_log("Platform movies loaded. Count: %d", log: .default, type: .debug, platformMovies.count)
    }
}

#Preview {
    PlatformView()
        .environmentObject(MovieDatabase())
}
