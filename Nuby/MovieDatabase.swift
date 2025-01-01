import Foundation
import SwiftUI
import os.log

class MovieDatabase: ObservableObject {
    @Published var movies: [Movie] = []
    @AppStorage("savedMovies") private var savedMoviesData: Data = Data()
    private let maxMoviesLimit = 100

    init() {
        loadMovies()
    }

    private func loadMovies() {
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
                }
            } catch {
                DispatchQueue.main.async {
                    self.movies = []
                }
            }
        }
    }

    func saveMovies() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            do {
                let encoder = JSONEncoder()
                let encodedData = try encoder.encode(self.movies)

                DispatchQueue.main.async {
                    self.savedMoviesData = encodedData
                }
            } catch {
                // Handle save error
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
