import Foundation
import SwiftUI
import os.log

class MovieDatabase: ObservableObject {
    @Published var movies: [Movie] = []
    @AppStorage("savedMovies") private var savedMoviesData: Data = Data()
    private let maxMoviesLimit = 100
    
    init() {
        Logger.log("Initializing MovieDatabase", level: .info)
        loadMovies()
    }
    
    private func loadMovies() {
        guard !savedMoviesData.isEmpty else {
            Logger.log("No saved movies data found", level: .info)
            DispatchQueue.main.async {
                self.movies = []
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                Logger.log("Self reference lost while loading movies", level: .error)
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let loadedMovies = try decoder.decode([Movie].self, from: self.savedMoviesData)
                DispatchQueue.main.async {
                    self.movies = loadedMovies
                    Logger.log("Successfully loaded \(loadedMovies.count) movies", level: .info)
                }
            } catch {
                Logger.handle(error, context: "Failed to decode saved movies data", level: .error)
                DispatchQueue.main.async {
                    self.movies = []
                }
            }
        }
    }
    
    private func saveMovies() {
        Logger.log("Starting movie save operation", level: .debug)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else {
                Logger.log("Self reference lost while saving movies", level: .error)
                return
            }
            
            do {
                let encoder = JSONEncoder()
                let encodedData = try encoder.encode(self.movies)
                
                DispatchQueue.main.async {
                    self.savedMoviesData = encodedData
                    Logger.log("Successfully saved \(self.movies.count) movies", level: .info)
                }
            } catch {
                Logger.handle(error, context: "Failed to encode movies for saving", level: .error)
            }
        }
    }
    
    func addMovie(_ movie: Movie) {
        guard movies.count < maxMoviesLimit else {
            Logger.log("Cannot add movie: Maximum limit of \(maxMoviesLimit) reached", level: .warning)
            return
        }
        
        guard !movies.contains(where: { $0.id == movie.id }) else {
            Logger.log("Cannot add movie: \(movie.title) already exists", level: .warning)
            return
        }
        
        DispatchQueue.main.async {
            self.movies.append(movie)
            self.saveMovies()
            Logger.log("Added movie: \(movie.title)", level: .info)
        }
    }
    
    func removeMovie(_ movie: Movie) {
        DispatchQueue.main.async {
            self.movies.removeAll(where: { $0.id == movie.id })
            self.saveMovies()
            Logger.log("Removed movie: \(movie.title)", level: .info)
        }
    }
    
    func updateMovie(_ updatedMovie: Movie) {
        guard let index = movies.firstIndex(where: { $0.id == updatedMovie.id }) else {
            Logger.log("Cannot update movie: \(updatedMovie.title) not found", level: .warning)
            return
        }
        
        DispatchQueue.main.async {
            self.movies[index] = updatedMovie
            self.saveMovies()
            Logger.log("Updated movie: \(updatedMovie.title)", level: .info)
        }
    }
    
    func searchMovies(query: String) -> [Movie] {
        Logger.log("Searching movies with query: \(query)", level: .debug)
        let results = movies.filter { movie in
            movie.title.localizedCaseInsensitiveContains(query)
        }
        Logger.log("Found \(results.count) movies matching query: \(query)", level: .debug)
        return results
    }
}
