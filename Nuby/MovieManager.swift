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
    @Published var searchState: MovieSearchState = .idle
    
    /// Potential error during movie operations
    @Published var error: MovieOperationError?
    
    /// Movie database for persistent storage
    private let movieDatabase: MovieDatabase
    
    /// Cancellables for storing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Computed property for recent movies
    var recentMovies: [Movie] {
        let movies = movieDatabase.movies
        Logger.log("Retrieving recent movies. Total count: \(movies.count)", level: .debug)
        return movies
    }
    
    init(movieDatabase: MovieDatabase) {
        Logger.log("Initializing MovieManager", level: .info)
        self.movieDatabase = movieDatabase
    }
    
    func searchMovies(query: String) {
        Logger.log("Starting movie search with query: \(query)", level: .debug)
        searchState = .searching
        
        // Validate query
        guard !query.isEmpty else {
            Logger.log("Empty search query, showing all movies", level: .debug)
            filteredMovies = movies
            searchState = .idle
            return
        }
        
        // Perform search
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                Logger.log("Self reference lost during search", level: .error)
                return
            }
            
            let results = self.movieDatabase.searchMovies(query: query)
            
            DispatchQueue.main.async {
                self.filteredMovies = results
                self.searchState = .idle
                Logger.log("Search completed. Found \(results.count) results", level: .debug)
            }
        }
    }
    
    func addMovie(_ movie: Movie) {
        Logger.log("Adding movie: \(movie.title)", level: .info)
        do {
            try validateMovie(movie)
            movieDatabase.addMovie(movie)
        } catch {
            Logger.handle(error, context: "Failed to add movie", level: .error)
            self.error = .addFailed
        }
    }
    
    func updateMovie(_ movie: Movie) {
        Logger.log("Updating movie: \(movie.title)", level: .info)
        do {
            try validateMovie(movie)
            movieDatabase.updateMovie(movie)
        } catch {
            Logger.handle(error, context: "Failed to update movie", level: .error)
            self.error = .updateFailed
        }
    }
    
    func deleteMovie(_ movie: Movie) {
        Logger.log("Deleting movie: \(movie.title)", level: .info)
        movieDatabase.removeMovie(movie)
    }
    
    private func validateMovie(_ movie: Movie) throws {
        Logger.log("Validating movie: \(movie.title)", level: .debug)
        
        guard !movie.title.isEmpty else {
            Logger.log("Movie validation failed: Empty title", level: .warning)
            throw MovieOperationError.invalidTitle
        }
        
        // Validate cinema information for cinema source
        if movie.source == .cinema {
            guard !movie.cinema.name.isEmpty, !movie.cinema.location.isEmpty else {
                Logger.log("Movie validation failed: Invalid cinema information", level: .warning)
                throw MovieOperationError.invalidCinemaInfo
            }
        }
        
        Logger.log("Movie validation successful", level: .debug)
    }
}

/// Represents the current state of a movie search operation
enum MovieSearchState {
    case idle
    case searching
}

/// Custom errors that can occur during movie operations
enum MovieOperationError: Error {
    case addFailed
    case updateFailed
    case deleteFailed
    case invalidTitle
    case invalidCinemaInfo
    case invalidURL
    
    var localizedDescription: String {
        switch self {
        case .addFailed:
            return "Failed to add movie"
        case .updateFailed:
            return "Failed to update movie"
        case .deleteFailed:
            return "Failed to delete movie"
        case .invalidTitle:
            return "Movie title cannot be empty"
        case .invalidCinemaInfo:
            return "Invalid cinema information"
        case .invalidURL:
            return "Invalid movie URL"
        }
    }
}
