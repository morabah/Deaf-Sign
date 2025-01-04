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

@MainActor

class MovieManager: ObservableObject {
    /// Published array of movies for reactive UI updates
    @Published private(set) var movies: [Movie] = []
    
    /// Filtered movies based on search query
    @Published private(set) var filteredMovies: [Movie] = []
    
    /// Current state of the search operation
    @Published private(set) var searchState: MovieSearchState = .idle
    
    /// Potential error during movie operations
    @Published private(set) var error: MovieOperationError?
    
    /// Search text for debouncing
    @Published var searchText = "" {
        didSet {
            Task { @MainActor in
                await performSearch(query: searchText)
            }
        }
    }
    
    /// Movie database for persistent storage
    private let movieDatabase: MovieDatabase
    private var cancellables = Set<AnyCancellable>()
    
    init(movieDatabase: MovieDatabase) {
        Logger.log("Initializing MovieManager", level: .info)
        self.movieDatabase = movieDatabase
        
        // Set up movie database observation
        movieDatabase.$movies
            .receive(on: DispatchQueue.main)
            .sink { [weak self] movies in
                self?.movies = movies
                self?.filteredMovies = movies // Reset filtered movies when database updates
                Logger.log("Updated movies from database. Count: \(movies.count)", level: .debug)
            }
            .store(in: &cancellables)
        
        // Observe database errors
        movieDatabase.$error
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.error = .databaseError(error)
                Logger.log("Database error received: \(error.localizedDescription)", level: .error)
            }
            .store(in: &cancellables)
    }
    
    func addMovie(_ movie: Movie) async throws {
        Logger.log("Adding movie: \(movie.title)", level: .info)
        try validateMovie(movie)
        try await movieDatabase.addMovie(movie)
    }
    
    func updateMovie(_ movie: Movie) async throws {
        Logger.log("Updating movie: \(movie.title)", level: .info)
        try validateMovie(movie)
        try await movieDatabase.updateMovie(movie)
    }
    
    func deleteMovie(_ movie: Movie) async throws {
        Logger.log("Deleting movie: \(movie.title)", level: .info)
        try await movieDatabase.deleteMovie(movie)
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
    }
    
    private func performSearch(query: String) async {
        Logger.log("Performing search with query: \(query)", level: .debug)
        searchState = .searching
        
        // Validate query
        guard !query.isEmpty else {
            Logger.log("Empty search query, showing all movies", level: .debug)
            filteredMovies = movies
            searchState = .idle
            return
        }
        
        // Perform search on background thread
        let results = await Task.detached(priority: .userInitiated) { [movies] in
            movies.filter { movie in
                movie.title.localizedCaseInsensitiveContains(query) ||
                movie.cinema.name.localizedCaseInsensitiveContains(query) ||
                movie.cinema.location.localizedCaseInsensitiveContains(query)
            }
        }.value
        
        // Update state on main actor
        filteredMovies = results
        searchState = .idle
        Logger.log("Search completed. Found \(results.count) results", level: .debug)
    }
}

/// Represents the current state of a movie search operation
enum MovieSearchState {
    case idle
    case searching
}

/// Custom errors that can occur during movie operations
enum MovieOperationError: Error, LocalizedError {
    case addFailed
    case updateFailed
    case deleteFailed
    case databaseError(Error)
    case invalidTitle
    case invalidCinemaInfo
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .addFailed:
            return "Failed to add movie"
        case .updateFailed:
            return "Failed to update movie"
        case .deleteFailed:
            return "Failed to delete movie"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        case .invalidTitle:
            return "Movie title cannot be empty"
        case .invalidCinemaInfo:
            return "Invalid cinema information"
        case .invalidURL:
            return "Invalid movie URL"
        }
    }
}
