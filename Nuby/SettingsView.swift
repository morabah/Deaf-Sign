import SwiftUI
import os

/// Main settings view for managing movie library and app preferences
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var movieDatabase: MovieDatabase
    @StateObject private var movieManager: MovieManager
    
    // MARK: - State Variables
    @State private var searchText = ""
    @State private var editingMovie: Movie?
    @State private var isAddingMovie = false
    @State private var showDeleteConfirmation = false
    @State private var movieToDelete: Movie?
    
    // MARK: - Initialization
    init(movieDatabase: MovieDatabase? = nil) {
        let db = movieDatabase ?? MovieDatabase()
        self.movieDatabase = db
        // Initialize MovieManager with the same database instance
        _movieManager = StateObject(wrappedValue: MovieManager(movieDatabase: db))
    }
    
    // MARK: - Computed Properties
    private var filteredMovies: [Movie] {
        if searchText.isEmpty {
            return movieDatabase.movies
        }
        return movieDatabase.movies.filter { 
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.source.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Main View
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText, movieManager: movieManager)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Movie list
                List {
                    ForEach(filteredMovies) { movie in
                        MovieRowView(movie: movie)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    movieToDelete = movie
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    editingMovie = movie
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(.insetGrouped)
                
                // Add button
                Button(action: { isAddingMovie = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add New Movie")
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Movie Library")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $editingMovie) { movie in
                MovieEditSheet(movie: movie, movieDatabase: movieDatabase)
            }
            .sheet(isPresented: $isAddingMovie) {
                MovieAddSheet(movieDatabase: movieDatabase, isPresented: $isAddingMovie)
            }
            .confirmationDialog("Delete Movie", isPresented: $showDeleteConfirmation, presenting: movieToDelete) { movie in
                Button("Delete", role: .destructive) {
                    withAnimation {
                        movieDatabase.removeMovie(movie)
                    }
                    movieToDelete = nil
                }
            } message: { movie in
                Text("Are you sure you want to delete '\(movie.title)'?")
            }
        }
    }
}

// MARK: - Supporting Views
struct MovieRowView: View {
    let movie: Movie
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(movie.title)
                .font(.headline)
            
            HStack {
                Label(movie.source.rawValue, systemImage: 
                    movie.source == .cinema ? "film" : "play.tv")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let date = movie.releaseDate {
                    Text(date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct MovieAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var movieDatabase: MovieDatabase
    @Binding var isPresented: Bool
    
    @State private var title = ""
    @State private var link = ""
    @State private var source: MovieSource = .cinema
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Movie Details")) {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Link", text: $link)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    
                    Picker("Source", selection: $source) {
                        Text("Cinema").tag(MovieSource.cinema)
                        Text("Platform").tag(MovieSource.platform)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addMovie() }
                        .disabled(title.isEmpty || link.isEmpty)
                }
            }
        }
    }
    
    private func addMovie() {
        let cinema = CinemaInformation(id: UUID(), name: "Default Cinema", location: "Unknown")
        let movie = Movie(
            id: UUID(),
            title: title,
            cinema: cinema,
            source: source,
            posterImage: link,
            releaseDate: nil
        )
        
        movieDatabase.addMovie(movie)
        isPresented = false
    }
}

struct MovieEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let movie: Movie
    @ObservedObject var movieDatabase: MovieDatabase
    
    @State private var title: String
    @State private var link: String
    @State private var source: MovieSource
    
    init(movie: Movie, movieDatabase: MovieDatabase) {
        self.movie = movie
        self.movieDatabase = movieDatabase
        _title = State(initialValue: movie.title)
        _link = State(initialValue: movie.posterImage ?? "")
        _source = State(initialValue: movie.source)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Movie Details")) {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Link", text: $link)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    
                    Picker("Source", selection: $source) {
                        Text("Cinema").tag(MovieSource.cinema)
                        Text("Platform").tag(MovieSource.platform)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Edit Movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(title.isEmpty || link.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        let cinema = CinemaInformation(id: movie.cinema.id, name: movie.cinema.name, location: movie.cinema.location)
        let updatedMovie = Movie(
            id: movie.id,
            title: title,
            cinema: cinema,
            source: source,
            posterImage: link,
            releaseDate: movie.releaseDate
        )
        
        movieDatabase.updateMovie(updatedMovie)
        dismiss()
    }
}

// An extension to the Logger class to handle logging
extension Logger {
    // Log a message with a level
    static func log(_ message: String, level: LogLevel) {
        os_log("%{public}@", log: .default, type: level.osLogType, message)
    }
    
    // Handle an error with a context and level
    static func handle(_ error: Error, context: String, level: LogLevel) {
        os_log("%{public}@: %{public}@", log: .default, type: level.osLogType, context, error.localizedDescription)
    }
}

// An extension to the LogLevel enum to get the OS log type
extension LogLevel {
    // Get the OS log type for the level
    var osLogType: OSLogType {
        switch self {
        case .debug:
            return .debug
        case .info:
            return .info
        case .warning:
            return .default
        case .error:
            return .error
        }
    }
}

// An enum for the log levels
enum LogLevel {
    case debug
    case info
    case warning
    case error
}
