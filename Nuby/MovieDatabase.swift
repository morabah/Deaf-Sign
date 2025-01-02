import Foundation
import SwiftUI
import os.log

class MovieDatabase: ObservableObject {
    @Published var movies: [Movie] = []
    @AppStorage("savedMovies") private var savedMoviesData: Data = Data()
    private let maxMoviesLimit = 200

    init() {
        loadMovies()
    }

    private func loadMovies() {
        Logger.log("Loading movies from storage", level: .debug)
        
        guard !savedMoviesData.isEmpty else {
            DispatchQueue.main.async {
                self.movies = []
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let decoder = JSONDecoder()
                let decodedMovies = try decoder.decode([Movie].self, from: self.savedMoviesData)

                DispatchQueue.main.async {
                    self.movies = decodedMovies
                    Logger.log("Successfully loaded \(decodedMovies.count) movies", level: .debug)
                }
            } catch {
                Logger.log("Failed to load movies: \(error.localizedDescription)", level: .error)
                DispatchQueue.main.async {
                    self.movies = []
                }
            }
        }
    }

    func saveMovies() {
        Logger.log("Saving movies to storage", level: .debug)
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            do {
                let encoder = JSONEncoder()
                let encodedData = try encoder.encode(self.movies)

                DispatchQueue.main.async {
                    self.savedMoviesData = encodedData
                    Logger.log("Successfully saved \(self.movies.count) movies", level: .debug)
                    
                    // Reload movies to ensure consistency
                    self.loadMovies()
                }
            } catch {
                Logger.log("Failed to save movies: \(error.localizedDescription)", level: .error)
            }
        }
    }

    func addMovie(_ movie: Movie) {
        guard movies.count < maxMoviesLimit else { return }
        DispatchQueue.main.async {
            self.movies.append(movie)
            self.saveMovies()
        }
    }

    func removeMovie(_ movie: Movie) {
        DispatchQueue.main.async {
            self.movies.removeAll { $0.id == movie.id }
            self.saveMovies()
        }
    }
    
    func updateMovie(_ updatedMovie: Movie) {
        Logger.log("Updating movie: \(updatedMovie.title)", level: .debug)
        
        DispatchQueue.main.async {
            if let index = self.movies.firstIndex(where: { $0.id == updatedMovie.id }) {
                self.movies[index] = updatedMovie
                self.saveMovies()
            }
        }
    }
    
    func searchMovies(query: String) -> [Movie] {
        let lowercasedQuery = query.lowercased()
        return movies.filter { movie in
            movie.title.lowercased().contains(lowercasedQuery) ||
            movie.source.rawValue.lowercased().contains(lowercasedQuery) ||
            (movie.cinema.name.lowercased().contains(lowercasedQuery)) ||
            (movie.cinema.location.lowercased().contains(lowercasedQuery))
        }
    }
}
