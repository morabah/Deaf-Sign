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
/// - Version: 1.0.1
/// - Author: Nuby Development Team
/// - Copyright: 2024 Nuby App

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
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // Search Bar
                    SearchBar(text: $searchText, movieManager: MovieManager(movieDatabase: movieDatabase))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    // Movie List
                    if cinemaMovies.isEmpty {
                        ProgressView("Loading movies...")
                            .padding()
                    } else if filteredMovies.isEmpty {
                        Text("No movies found")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        List(filteredMovies) { movie in
                            MovieRow(movie: movie)
                                .onTapGesture {
                                    selectedMovie = movie
                                    Logger.log("Selected movie: \(movie.title)", level: .debug)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .background(Color(.systemGroupedBackground))
                    }
                }
            }
            .navigationTitle("📦 Nuby Cinema")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                        Logger.log("Settings button pressed in CinemaView", level: .debug)
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
                        Logger.log("CinemaView dismissed", level: .debug)
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
                Logger.log("CinemaView appeared", level: .debug)
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
            Logger.log("Warning: Found a movie with an empty title.", level: .error)
        }
        
        Logger.log("Cinema movies loaded. Count: \(cinemaMovies.count)", level: .debug)
    }
}

// MARK: - Supporting Views


