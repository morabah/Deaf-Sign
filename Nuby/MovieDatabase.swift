import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import os.log
import Network

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
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.nuby.networkMonitor")
    private var isNetworkAvailable = true
    
    init() {
        setupNetworkMonitoring()
        setupAuthListener()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkAvailable = path.status == .satisfied
                
                if path.status == .satisfied {
                    Logger.log("Network connection established", level: .info)
                    // Retry any pending operations
                    if let self = self, self.movies.isEmpty {
                        self.setupMoviesListener()
                    }
                } else {
                    Logger.log("Network connection lost", level: .error)
                    self?.error = MovieError.networkError
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
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
        guard isNetworkAvailable else {
            self.error = MovieError.networkError
            return
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            Logger.log("No authenticated user found", level: .error)
            self.error = MovieError.notAuthenticated
            return
        }
        
        moviesListener?.remove()
        isLoading = true
        
        let query = db.collection("movies")
            .whereField("userId", isEqualTo: userId)
            .order(by: "updatedAt", descending: true)
            .limit(to: 100)  // Add reasonable limit for performance
        
        Logger.log("Setting up movies listener for user: \(userId)", level: .debug)
        
        moviesListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { 
                Logger.log("Self reference lost in snapshot listener", level: .error)
                return 
            }
            
            defer { 
                self.isLoading = false 
                Logger.log("Movies listener processing completed", level: .debug)
            }
            
            if let error = error {
                Logger.log("Error fetching movies: \(error.localizedDescription)", level: .error)
                if (error as NSError).domain == NSURLErrorDomain {
                    self.error = MovieError.networkError
                } else {
                    self.error = MovieError.databaseError(error)
                }
                return
            }
            
            guard let documents = snapshot?.documents else {
                Logger.log("No documents found in snapshot", level: .warning)
                self.movies = []
                return
            }
            
            Logger.log("Processing \(documents.count) movies", level: .debug)
            
            self.processMovieDocuments(documents)
        }
    }
    
    private func processMovieDocuments(_ documents: [QueryDocumentSnapshot]) {
        let processedMovies: [Movie] = documents.compactMap { document -> Movie? in
            do {
                var data = document.data()
                
                // Validate required fields
                guard let title = data["title"] as? String,
                      let sourceRaw = data["source"] as? String,
                      let source = MovieSource(rawValue: sourceRaw) else {
                    Logger.log("Invalid document format: \(document.documentID)", level: .error)
                    return nil
                }
                
                // Process ID
                let movieId = data["id"] as? String ?? UUID().uuidString
                guard UUID(uuidString: movieId) != nil else {
                    Logger.log("Invalid UUID format: \(movieId)", level: .error)
                    return nil
                }
                data["id"] = movieId
                
                // Process metadata
                data["firestoreId"] = document.documentID
                data["userId"] = Auth.auth().currentUser?.uid
                
                // Process dates with better error handling
                let dateFormatter = ISO8601DateFormatter()
                for field in ["createdAt", "updatedAt", "releaseDate"] {
                    if let timestamp = data[field] as? Timestamp {
                        data[field] = dateFormatter.string(from: timestamp.dateValue())
                    }
                }
                
                // Process cinema data
                let cinema = data["cinema"] as? [String: Any] ?? [:]
                data["cinema"] = [
                    "id": cinema["id"] as? String ?? UUID().uuidString,
                    "name": cinema["name"] as? String ?? "",
                    "location": cinema["location"] as? String ?? ""
                ]
                
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(Movie.self, from: jsonData)
                
            } catch {
                Logger.log("Error processing document \(document.documentID): \(error)", level: .error)
                return nil
            }
        }
        
        self.movies = processedMovies
        Logger.log("Successfully processed \(processedMovies.count) movies", level: .info)
    }
    
    /// Add a new movie to the database
    /// - Parameter movie: The movie to add
    func addMovie(_ movie: Movie) async throws {
        guard isNetworkAvailable else {
            throw MovieError.networkError
        }
        
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
        guard isNetworkAvailable else {
            throw MovieError.networkError
        }
        
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
            try await db.collection("movies").document(movie.firestoreId).updateData(data)
            Logger.log("Successfully updated movie: \(movie.title)", level: .info)
        } catch {
            Logger.log("Failed to update movie: \(error.localizedDescription)", level: .error)
            throw MovieError.databaseError(error)
        }
    }
    
    /// Delete a movie from the database
    /// - Parameter movie: The movie to delete
    func deleteMovie(_ movie: Movie) async throws {
        guard isNetworkAvailable else {
            throw MovieError.networkError
        }
        
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
    
    /// Filter movies based on title and source
    /// - Parameters:
    ///   - title: Optional title to filter by
    ///   - source: Optional source to filter by
    /// - Returns: Filtered array of movies
    func filterMovies(title: String?, source: MovieSource?) -> [Movie] {
        return movies.filter { movie in
            (title == nil || movie.title.localizedCaseInsensitiveContains(title!)) &&
            (source == nil || movie.source == source!)
        }
    }
    
    /// Search for movies based on title
    /// - Parameter query: The search query
    /// - Returns: Array of movies with matching titles
    func searchMovies(query: String) -> [Movie] {
        if query.isEmpty {
            return movies
        }
        
        // Clean and prepare the search query
        let searchQuery = query.trimmingCharacters(in: .whitespaces).lowercased()
        
        // Filter movies by exact title match only
        return movies.filter { movie in
            // Only check the title field, converted to lowercase
            let titleWords = movie.title.lowercased().split(separator: " ")
            
            // Check if any title word starts with the search query
            return titleWords.contains { word in
                word.hasPrefix(searchQuery)
            }
        }
    }
    
    deinit {
        networkMonitor.cancel()
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
        moviesListener?.remove()
    }
}
