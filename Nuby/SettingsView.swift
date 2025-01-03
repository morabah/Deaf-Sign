import SwiftUI
import os.log

/// Main settings view for managing movie library and app preferences
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var movieDatabase: MovieDatabase
    @StateObject private var movieManager: MovieManager
    
    @State private var searchText = ""
    @State private var editingMovie: Movie?
    @State private var isAddingMovie = false
    @State private var showDeleteConfirmation = false
    @State private var movieToDelete: Movie?
    @State private var showSuccessToast = false
    @State private var toastMessage = ""
    
    init(movieDatabase: MovieDatabase? = nil) {
        let db = movieDatabase ?? MovieDatabase()
        self.movieDatabase = db
        _movieManager = StateObject(wrappedValue: MovieManager(movieDatabase: db))
    }
    
    private var filteredMovies: [Movie] {
        if searchText.isEmpty {
            return movieDatabase.movies
        }
        return movieDatabase.movies.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.source.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                // Main Content
                VStack(spacing: 0) {
                    // Search Bar
                    SearchBar(text: $searchText, movieManager: movieManager)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    // Movie List
                    List {
                        ForEach(filteredMovies) { movie in
                            MovieCardView(movie: movie)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        movieToDelete = movie
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }
                                    
                                    Button {
                                        editingMovie = movie
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color(.systemGroupedBackground))
                    
                    // Add Button
                    Button(action: { isAddingMovie = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                            Text("Add Movie")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                
                // Success Toast
                if showSuccessToast {
                    ToastView(message: toastMessage)
                        .transition(.move(edge: .top))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showSuccessToast = false
                                }
                            }
                        }
                }
            }
            .navigationTitle("Movie Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(item: $editingMovie) { movie in
                MovieEditSheet(movie: movie, movieDatabase: movieDatabase, onSave: {
                    toastMessage = "Movie updated successfully!"
                    showSuccessToast = true
                })
            }
            .sheet(isPresented: $isAddingMovie) {
                MovieAddSheet(movieDatabase: movieDatabase, isPresented: $isAddingMovie, onSave: {
                    toastMessage = "Movie added successfully!"
                    showSuccessToast = true
                })
            }
            .confirmationDialog("Delete Movie", isPresented: $showDeleteConfirmation, presenting: movieToDelete) { movie in
                Button("Delete", role: .destructive) {
                    withAnimation {
                        movieDatabase.removeMovie(movie)
                        toastMessage = "Movie deleted successfully!"
                        showSuccessToast = true
                    }
                }
            } message: { movie in
                Text("Are you sure you want to delete '\(movie.title)'?")
            }
        }
    }
}

// MARK: - Supporting Views

/// Card-style view for each movie
struct MovieCardView: View {
    let movie: Movie
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(movie.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Label(movie.source.rawValue, systemImage: movie.source == .cinema ? "film" : "tv")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let date = movie.releaseDate {
                    Text(date, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

/// Toast view for success messages
struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.top, 16)
    }
}

// MARK: - Sheets

struct MovieAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var movieDatabase: MovieDatabase
    @Binding var isPresented: Bool
    var onSave: () -> Void
    
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
                    Button("Add") {
                        addMovie()
                        onSave()
                    }
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
    var onSave: () -> Void
    
    @State private var title: String
    @State private var link: String
    @State private var source: MovieSource
    
    init(movie: Movie, movieDatabase: MovieDatabase, onSave: @escaping () -> Void) {
        self.movie = movie
        self.movieDatabase = movieDatabase
        self.onSave = onSave
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
                    Button("Save") {
                        saveChanges()
                        onSave()
                    }
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
