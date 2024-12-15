//test github

import Foundation
import SwiftUI

// MARK: - Movie Types

/// Source type for a movie (cinema or platform)
public enum MovieSource: String, Codable, Equatable {
    case cinema
    case platform
}

/// Cinema information
public struct CinemaInformation: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let name: String
    public let location: String
    
    public init(id: UUID = UUID(), name: String, location: String) {
        self.id = id
        self.name = name
        self.location = location
    }
    
    public static func == (lhs: CinemaInformation, rhs: CinemaInformation) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Movie information
public struct Movie: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let title: String
    public let cinema: CinemaInformation
    public let source: MovieSource
    public let posterImage: String?
    public let releaseDate: Date?
    
    public init(id: UUID = UUID(), title: String, cinema: CinemaInformation, source: MovieSource, posterImage: String? = nil, releaseDate: Date? = nil) {
        self.id = id
        self.title = title
        self.cinema = cinema
        self.source = source
        self.posterImage = posterImage
        self.releaseDate = releaseDate
    }
    
    public static func == (lhs: Movie, rhs: Movie) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - View Types

/// Type of movie view to display
public enum MovieViewType: String, CaseIterable, Codable {
    case cinema = "Cinema"
    case platform = "Platform"
}

// MARK: - User Movie Types

struct UserMovie: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var link: String
    var type: MovieViewType
    
    init(name: String, link: String, type: MovieViewType) {
        self.id = UUID()
        self.name = name
        self.link = link
        self.type = type
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: UserMovie, rhs: UserMovie) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - State Management

/// State of movie search operation
public enum SearchState {
    case idle
    case searching
    case completed
    case error(String)
}

// MARK: - Error Types

/// Movie-related errors
public enum MovieError: LocalizedError {
    case loadFailed
    case searchFailed
    case invalidData
    case networkError
    
    public var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "Failed to load movies"
        case .searchFailed:
            return "Failed to search movies"
        case .invalidData:
            return "Invalid movie data"
        case .networkError:
            return "Network connection error"
        }
    }
}

// MARK: - User Movie Store

@MainActor
class UserMovieStore: ObservableObject {
    @Published var userMovies: [UserMovie] = []
    
    init() {
        clearUserMovies() // Clear old user movies data
        loadUserMovies()
    }
    
    private func loadUserMovies() {
        if let data = UserDefaults.standard.data(forKey: "userMovies"),
           let decodedMovies = try? JSONDecoder().decode([UserMovie].self, from: data) {
            self.userMovies = decodedMovies
        }
    }
    
    func saveUserMovies() {
        if let encoded = try? JSONEncoder().encode(userMovies) {
            UserDefaults.standard.set(encoded, forKey: "userMovies")
        }
    }
    
    func addUserMovie(_ movie: UserMovie) {
        userMovies.append(movie)
        saveUserMovies()
    }
    
    func removeUserMovie(_ movie: UserMovie) {
        userMovies.removeAll { $0.id == movie.id }
        saveUserMovies()
    }
    
    func clearUserMovies() {
        UserDefaults.standard.removeObject(forKey: "userMovies")
    }
    
    var cinemaMovies: [UserMovie] {
        userMovies.filter { $0.type == .cinema }
    }
    
    var platformMovies: [UserMovie] {
        userMovies.filter { $0.type == .platform }
    }
}
