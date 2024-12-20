import Foundation
import SwiftUI
import os.log

/// MovieDatabase: A Comprehensive Movie Data Management System
///
/// Purpose:
/// Provide a robust, efficient, and flexible mechanism for managing
/// movie data persistence, retrieval, and synchronization in the Nuby app.
///
/// Key Components:
/// - MovieType: Enum for categorizing movie sources
/// - MovieItem: Struct representing individual movie metadata
/// - MovieDatabase: Class managing movie data lifecycle
///
/// Core Functionalities:
/// - Persistent movie storage
/// - Data encoding and decoding
/// - Movie addition and removal
/// - Limit enforcement
///
/// Design Principles:
/// - Data integrity
/// - Performance optimization
/// - Scalability
/// - User privacy
///
/// Technical Details:
/// - Uses AppStorage for lightweight persistence
/// - Codable protocol for easy serialization
/// - UUID-based unique identification
/// - Reactive UI updates with @Published
///
/// Storage Characteristics:
/// - Maximum 100 movies
/// - Unique movie entries
/// - Type-safe movie categorization
///
/// Performance Considerations:
/// - Minimal memory overhead
/// - Efficient data operations
/// - Quick serialization/deserialization
///
/// - Version: 1.0.0
/// - Author: Nuby Development Team
/// - Copyright: 2024 Nuby App

/// Represents the type of movie source
enum MovieType: String, Codable {
    case cinema = "Cinema"
    case platform = "Platform"
}

/// Represents a single movie item with essential metadata
struct MovieItem: Identifiable, Codable {
    /// Unique identifier for the movie
    let id: UUID
    
    /// Title of the movie
    var title: String
    
    /// URL or reference link for the movie
    var url: String
    
    /// Type of movie source
    var type: MovieType
    
    /// Initializes a new movie item
    /// - Parameters:
    ///   - title: Movie title
    ///   - url: Movie reference URL
    ///   - type: Movie source type
    init(title: String, url: String, type: MovieType) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.type = type
    }
}

/// Manages movie data persistence and retrieval
class MovieDatabase: ObservableObject {
    /// Published array of movies to trigger UI updates
    @Published var movies: [Movie] = []
    
    /// Persistent storage for movies using AppStorage
    @AppStorage("savedMovies") private var savedMoviesData: Data = Data()
    
    /// Maximum number of movies allowed in the database
    private let maxMoviesLimit = 100
    
    /// Initializes the movie database and loads existing movies
    init() {
        os_log("Initializing MovieDatabase", log: .default, type: .debug)
        loadMovies()
    }
    
    /// Loads movies from persistent storage
    private func loadMovies() {
        guard !savedMoviesData.isEmpty else {
            os_log("No saved movies data found", log: .default, type: .debug)
            DispatchQueue.main.async {
                self.movies = []
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let decoder = JSONDecoder()
                let loadedMovies = try decoder.decode([Movie].self, from: self.savedMoviesData)
                
                DispatchQueue.main.async {
                    self.movies = loadedMovies
                    os_log("Loaded %d movies from storage", log: .default, type: .debug, loadedMovies.count)
                }
            } catch {
                os_log("Error loading movies: %{public}@", log: .default, type: .error, error.localizedDescription)
                DispatchQueue.main.async {
                    self.movies = []
                }
            }
        }
    }
    
    /// Saves movies to persistent storage
    private func saveMovies() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let encoder = JSONEncoder()
                self.savedMoviesData = try encoder.encode(self.movies)
                os_log("Saved %d movies to storage", log: .default, type: .debug, self.movies.count)
            } catch {
                os_log("Error saving movies: %{public}@", log: .default, type: .error, error.localizedDescription)
            }
        }
    }
    
    /// Adds a new movie to the database
    func addMovie(_ movie: Movie) {
        guard movies.count < maxMoviesLimit else {
            os_log("Maximum movies limit reached", log: .default, type: .error)
            return
        }
        
        guard !movies.contains(where: { $0.id == movie.id }) else {
            os_log("Movie already exists", log: .default, type: .debug)
            return
        }
        
        movies.append(movie)
        saveMovies()
        os_log("Added movie: %{public}@", log: .default, type: .debug, movie.title)
    }
    
    /// Removes a movie from the database
    func removeMovie(_ movie: Movie) {
        movies.removeAll(where: { $0.id == movie.id })
        saveMovies()
        os_log("Removed movie: %{public}@", log: .default, type: .debug, movie.title)
    }
    
    /// Searches movies based on a query
    func searchMovies(query: String) -> [Movie] {
        let results = movies.filter { movie in
            movie.title.localizedCaseInsensitiveContains(query)
        }
        os_log("Found %d movies for query: %{public}@", log: .default, type: .debug, results.count, query)
        return results
    }
    
    /// Updates an existing movie in the database
    func updateMovie(_ updatedMovie: Movie) {
        guard let index = movies.firstIndex(where: { $0.id == updatedMovie.id }) else {
            os_log("Movie not found for update: %{public}@", log: .default, type: .error, updatedMovie.title)
            return
        }
        
        movies[index] = updatedMovie
        saveMovies()
        os_log("Updated movie: %{public}@", log: .default, type: .debug, updatedMovie.title)
    }
}
