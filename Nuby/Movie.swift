//test github 2
//git hup test 3
//git tst 4
//test 4 branch
//test 5 branch xcode 

import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Movie Types

/// Source type for a movie (cinema or platform)
public enum MovieSource: String, Codable, Equatable {
    case cinema = "Cinema"
    case platform = "Platform"
}

/// Cinema information
public struct CinemaInformation: Codable, Equatable {
    public let id: UUID
    public let name: String
    public let location: String
    
    public init(id: UUID, name: String, location: String) {
        self.id = id
        self.name = name
        self.location = location
    }
}

/// Movie information with optimized memory management
public struct Movie: Identifiable, Codable, Equatable {
    public let id: UUID
    public let firestoreId: String
    public let title: String
    public let cinema: CinemaInformation
    public let source: MovieSource
    public let posterImage: String?
    public let releaseDate: Date?
    public let userId: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(id: UUID = UUID(),
               firestoreId: String = "",
               title: String,
               cinema: CinemaInformation,
               source: MovieSource,
               posterImage: String? = nil,
               releaseDate: Date? = nil,
               userId: String? = nil,
               createdAt: Date = Date(),
               updatedAt: Date = Date()) {
        self.id = id
        self.firestoreId = firestoreId
        self.title = title
        self.cinema = cinema
        self.source = source
        self.posterImage = posterImage
        self.releaseDate = releaseDate
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, firestoreId, title, cinema, source, posterImage, releaseDate, userId, createdAt, updatedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        firestoreId = try container.decode(String.self, forKey: .firestoreId)
        title = try container.decode(String.self, forKey: .title)
        cinema = try container.decode(CinemaInformation.self, forKey: .cinema)
        source = try container.decode(MovieSource.self, forKey: .source)
        posterImage = try container.decodeIfPresent(String.self, forKey: .posterImage)
        releaseDate = try container.decodeIfPresent(Date.self, forKey: .releaseDate)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(firestoreId, forKey: .firestoreId)
        try container.encode(title, forKey: .title)
        try container.encode(cinema, forKey: .cinema)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(posterImage, forKey: .posterImage)
        try container.encodeIfPresent(releaseDate, forKey: .releaseDate)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
    
    public static func == (lhs: Movie, rhs: Movie) -> Bool {
        return lhs.id == rhs.id &&
               lhs.firestoreId == rhs.firestoreId &&
               lhs.title == rhs.title &&
               lhs.cinema == rhs.cinema &&
               lhs.source == rhs.source &&
               lhs.posterImage == rhs.posterImage &&
               lhs.releaseDate == rhs.releaseDate &&
               lhs.userId == rhs.userId &&
               lhs.createdAt == rhs.createdAt &&
               lhs.updatedAt == rhs.updatedAt
    }
}

// MARK: - Movie Errors
public enum MovieError: LocalizedError {
    case notAuthenticated
    case invalidMovieId
    case databaseError(Error)
    case invalidData
    case networkError
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Authentication required"
        case .invalidMovieId:
            return "Invalid movie ID"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid movie data"
        case .networkError:
            return "Network error occurred"
        }
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
