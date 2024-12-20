import Foundation
import Combine
import SwiftUI
import os.log

/// MovieManager: A Comprehensive Movie Data Management and Search System
///
/// Purpose:
/// Provide a robust, reactive, and efficient mechanism for managing
/// movie data, searching, and state tracking in the Nuby app.
///
/// Key Features:
/// - Dynamic movie search
/// - State-based search management
/// - Error handling
/// - Reactive data updates
///
/// Design Principles:
/// - Reactive programming paradigm
/// - Comprehensive error management
/// - Performance optimization
/// - Clean architectural separation
///
/// Component Responsibilities:
/// - Movie data storage
/// - Search query processing
/// - State management
/// - Error tracking
///
/// Technical Details:
/// - Uses Combine framework for reactive programming
/// - Supports complex search scenarios
/// - Provides detailed search states
///
/// Performance Considerations:
/// - Efficient search algorithms
/// - Minimal memory overhead
/// - Non-blocking search operations
///
/// Error Handling:
/// - Granular error types
/// - Comprehensive error logging
/// - Graceful error recovery
///
/// - Version: 1.0.0
/// - Author: Nuby Development Team
/// - Copyright: 2024 Nuby App

class MovieManager: ObservableObject {
    /// Published array of movies for reactive UI updates
    @Published var movies: [Movie] = []
    
    /// Filtered movies based on search query
    @Published var filteredMovies: [Movie] = []
    
    /// Current state of the search operation
    @Published var searchState: SearchState = .idle
    
    /// Potential error during movie operations
    @Published var error: MovieError?
    
    /// Movie database for persistent storage
    private let movieDatabase: MovieDatabase
    
    /// Computed property for recent movies
    var recentMovies: [Movie] {
        let movies = movieDatabase.movies
        Logger.log("Retrieving recent movies from MovieDatabase. Total count: \(movies.count)", level: .debug)
        for movie in movies {
            Logger.log("Recent Movie - Title: \(movie.title), Source: \(movie.source)", level: .debug)
        }
        return movies
    }
    
    /// Initialize MovieManager
    init(movieDatabase: MovieDatabase = MovieDatabase()) {
        self.movieDatabase = movieDatabase
        Logger.log("MovieManager initialized", level: .debug)
        
        // Set initial movies
        self.movies = movieDatabase.movies
        self.filteredMovies = movies
        
        // Observe changes in MovieDatabase
        movieDatabase.objectWillChange.sink { [weak self] _ in
            self?.movies = self?.movieDatabase.movies ?? []
            self?.filteredMovies = self?.movies ?? []
        }.store(in: &cancellables)
    }
    
    /// Cancellables for storing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Searches movies based on a given query
    func searchMovies(query: String) {
        Logger.log("Searching movies - Initial query: \(query)", level: .debug)
        
        // Reset to full list if query is empty
        guard !query.isEmpty else {
            DispatchQueue.main.async {
                self.filteredMovies = self.movies
                self.searchState = .idle
            }
            return
        }
        
        // Perform search on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let lowercasedQuery = query.lowercased()
            let results = self.movies.filter { movie in
                let titleMatch = movie.title.lowercased().contains(lowercasedQuery)
                let cinemaMatch = movie.cinema.name.lowercased().contains(lowercasedQuery)
                return titleMatch || cinemaMatch
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.filteredMovies = results
                self.searchState = results.isEmpty ? .error("No movies found for the query: \(query)") : .completed
                Logger.log("Found \(results.count) movies for query: \(query)", level: .debug)
            }
        }
    }
    
    /// Adds a new movie to the database
    func addMovie(_ movie: Movie) {
        movieDatabase.addMovie(movie)
    }
    
    /// Removes a movie from the database
    func removeMovie(_ movie: Movie) {
        movieDatabase.removeMovie(movie)
    }
    
    /// Handles input system errors
    func handleInputSystemError(_ error: Error) {
        // Log the error for debugging purposes
        Logger.log("Input System Error: \(error.localizedDescription)", level: .error)
        
        // Notify the user if necessary
        // This could be an alert or a UI message
        // Example: showAlert(with: "An input error occurred. Please try again.")
        
        // Attempt recovery if possible
        // Example: resetInputSession() or retryOperation()
    }
    
    /// Example method to show an alert (UI implementation needed)
    private func showAlert(with message: String) {
        // Implement UI alert to notify the user
        // This is a placeholder for actual UI code
    }
    
    /// Example method to reset input session (implementation needed)
    private func resetInputSession() {
        // Implement logic to reset the input session
        // This is a placeholder for actual recovery code
    }
}
