import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import os.log

/// Class responsible for managing the movie database
@MainActor
class MovieDatabase: ObservableObject {
    /// Published array of movies
    @Published private(set) var movies: [Movie] = []
    @Published private(set) var isLoading = false
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    private var authListener: AuthStateDidChangeListenerHandle?
    private var moviesListener: ListenerRegistration?
    
    init() {
        setupAuthListener()
    }
    
    private func setupAuthListener() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            if let user = user {
                Logger.log("User authenticated: \(user.uid)", level: .info)
                self?.setupMoviesListener()
            } else {
                Logger.log("User signed out, removing listeners", level: .info)
                self?.moviesListener?.remove()
                self?.moviesListener = nil
                self?.movies = []
            }
        }
    }
    
    private func setupMoviesListener() {
        guard let userId = Auth.auth().currentUser?.uid else {
            Logger.log("No authenticated user found", level: .error)
            return
        }
        
        moviesListener?.remove()
        isLoading = true
        
        let query = db.collection("movies")
            .whereField("userId", isEqualTo: userId)
            .order(by: "updatedAt", descending: true)
        
        Logger.log("Setting up movies listener for user: \(userId)", level: .debug)
        
        moviesListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            defer { self.isLoading = false }
            
            if let error = error {
                Logger.log("Error fetching movies: \(error.localizedDescription)", level: .error)
                self.error = error
                return
            }
            
            guard let documents = snapshot?.documents else {
                Logger.log("No documents found in snapshot", level: .warning)
                self.movies = []
                return
            }
            
            Logger.log("Fetched \(documents.count) movies", level: .debug)
            
            self.movies = documents.compactMap { document in
                do {
                    var data = document.data()
                    Logger.log("Processing document: \(document.documentID)", level: .debug)
                    
                    // Ensure required fields exist
                    guard let title = data["title"] as? String,
                          let sourceRaw = data["source"] as? String,
                          let source = MovieSource(rawValue: sourceRaw) else {
                        Logger.log("Missing required fields in document: \(document.documentID)", level: .error)
                        return nil
                    }
                    
                    // Handle ID conversion
                    if let idString = data["id"] as? String {
                        if let id = UUID(uuidString: idString) {
                            data["id"] = id.uuidString // Keep as string for JSON serialization
                        } else {
                            Logger.log("Invalid UUID string in document: \(idString)", level: .error)
                            return nil
                        }
                    } else {
                        data["id"] = UUID().uuidString // Keep as string for JSON serialization
                    }
                    
                    // Add Firestore ID and userId
                    data["firestoreId"] = document.documentID
                    data["userId"] = userId
                    
                    // Convert Timestamps to ISO8601 date strings for JSON serialization
                    if let createdAt = data["createdAt"] as? Timestamp {
                        let dateString = ISO8601DateFormatter().string(from: createdAt.dateValue())
                        data["createdAt"] = dateString
                    }
                    
                    if let updatedAt = data["updatedAt"] as? Timestamp {
                        let dateString = ISO8601DateFormatter().string(from: updatedAt.dateValue())
                        data["updatedAt"] = dateString
                    }
                    
                    if let releaseDate = data["releaseDate"] as? Timestamp {
                        let dateString = ISO8601DateFormatter().string(from: releaseDate.dateValue())
                        data["releaseDate"] = dateString
                    }
                    
                    // Ensure cinema information
                    if let cinemaData = data["cinema"] as? [String: Any] {
                        var updatedCinema = cinemaData
                        if cinemaData["id"] == nil {
                            updatedCinema["id"] = UUID().uuidString
                        } else if let cinemaId = cinemaData["id"] as? String {
                            updatedCinema["id"] = cinemaId
                        }
                        data["cinema"] = updatedCinema
                    } else {
                        data["cinema"] = [
                            "id": UUID().uuidString,
                            "name": "",
                            "location": ""
                        ]
                    }
                    
                    let jsonData = try JSONSerialization.data(withJSONObject: data)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let movie = try decoder.decode(Movie.self, from: jsonData)
                    return movie
                    
                } catch {
                    Logger.log("Error decoding movie document: \(error.localizedDescription)", level: .error)
                    return nil
                }
            }
            
            Logger.log("Successfully processed \(self.movies.count) movies", level: .info)
        }
    }
    
    /// Add a new movie to the database
    /// - Parameter movie: The movie to add
    func addMovie(_ movie: Movie) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw MovieError.notAuthenticated
        }
        
        // Create a dictionary manually to avoid Date serialization issues
        var data: [String: Any] = [
            "id": movie.id.uuidString,
            "userId": userId,
            "title": movie.title,
            "source": movie.source.rawValue,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]
        
        // Optional fields
        if let posterImage = movie.posterImage {
            data["posterImage"] = posterImage
        }
        
        if let releaseDate = movie.releaseDate {
            data["releaseDate"] = Timestamp(date: releaseDate)
        }
        
        // Cinema information
        data["cinema"] = [
            "id": movie.cinema.id.uuidString,
            "name": movie.cinema.name,
            "location": movie.cinema.location
        ]
        
        do {
            Logger.log("Adding movie: \(movie.title)", level: .debug)
            _ = try await db.collection("movies").addDocument(data: data)
            Logger.log("Successfully added movie: \(movie.title)", level: .info)
        } catch {
            Logger.log("Failed to add movie: \(error.localizedDescription)", level: .error)
            throw MovieError.databaseError(error)
        }
    }
    
    /// Update an existing movie in the database
    /// - Parameter movie: The updated movie
    func updateMovie(_ movie: Movie) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw MovieError.notAuthenticated
        }
        
        // Create a dictionary manually to avoid Date serialization issues
        var data: [String: Any] = [
            "id": movie.id.uuidString,
            "userId": userId,
            "title": movie.title,
            "source": movie.source.rawValue,
            "updatedAt": Timestamp(date: Date())
        ]
        
        // Optional fields
        if let posterImage = movie.posterImage {
            data["posterImage"] = posterImage
        }
        
        if let releaseDate = movie.releaseDate {
            data["releaseDate"] = Timestamp(date: releaseDate)
        }
        
        // Cinema information
        data["cinema"] = [
            "id": movie.cinema.id.uuidString,
            "name": movie.cinema.name,
            "location": movie.cinema.location
        ]
        
        do {
            Logger.log("Updating movie: \(movie.title)", level: .debug)
            try await db.collection("movies").document(movie.firestoreId).setData(data, merge: true)
            Logger.log("Successfully updated movie: \(movie.title)", level: .info)
        } catch {
            Logger.log("Failed to update movie: \(error.localizedDescription)", level: .error)
            throw MovieError.databaseError(error)
        }
    }
    
    /// Delete a movie from the database
    /// - Parameter movie: The movie to delete
    func deleteMovie(_ movie: Movie) async throws {
        guard Auth.auth().currentUser?.uid != nil else {
            throw MovieError.notAuthenticated
        }
        
        do {
            Logger.log("Deleting movie: \(movie.title)", level: .debug)
            try await db.collection("movies").document(movie.firestoreId).delete()
            Logger.log("Successfully deleted movie: \(movie.title)", level: .info)
        } catch {
            Logger.log("Failed to delete movie: \(error.localizedDescription)", level: .error)
            throw MovieError.databaseError(error)
        }
    }
    
    /// Search for movies based on a query string
    /// - Parameter query: The search query
    /// - Returns: Array of matching movies
    func searchMovies(query: String) -> [Movie] {
        if query.isEmpty {
            return movies
        }
        return movies.filter { movie in
            movie.title.localizedCaseInsensitiveContains(query) ||
            movie.cinema.name.localizedCaseInsensitiveContains(query) ||
            movie.cinema.location.localizedCaseInsensitiveContains(query)
        }
    }
    
    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
        moviesListener?.remove()
    }
}
