import SwiftUI
import Foundation
import os

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var movieDatabase: MovieDatabase
    
    @State private var isAddingMovie = false
    @State private var newMovieTitle = ""
    @State private var newMovieLink = ""
    @State private var selectedType: MovieSource? = nil
    @State private var showInvalidURLAlert = false
    
    @State private var editingMovie: Movie?
    @State private var editedTitle = ""
    @State private var editedLink = ""
    @State private var editedType: MovieSource?
    
    @State private var showDeleteConfirmation = false
    @State private var movieToDelete: Movie?
    
    init(movieDatabase: MovieDatabase? = nil) {
        self.movieDatabase = movieDatabase ?? MovieDatabase()
    }
    
    var body: some View {
        // Using NavigationStack for a more current UI approach.
        NavigationStack {
            List {
                Section(header: Text("Your Movie Library")) {
                    ForEach(movieDatabase.movies) { movie in
                        ZStack {
                            // Background styling is handled by the list style itself
                            rowContent(for: movie)
                        }
                        .listRowSeparator(.automatic)
                        .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
                        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                        .accessibilityElement(children: .combine)
                    }
                    .onDelete(perform: confirmDelete)
                }
                
                Section {
                    Button {
                        isAddingMovie = true
                    } label: {
                        Label("Add Movie", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue) // Ensure suitable color for both modes
                    }
                    .accessibilityLabel("Add a new movie")
                    .accessibilityHint("Opens a form to enter new movie details.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Invalid URL", isPresented: $showInvalidURLAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a valid URL that can be opened.")
            }
            .alert("Delete Movie", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let movie = movieToDelete {
                        movieDatabase.removeMovie(movie)
                        movieToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    movieToDelete = nil
                }
            } message: {
                Text("Are you sure you want to remove this movie?")
            }
            .sheet(isPresented: $isAddingMovie) {
                addMovieSheet
            }
        }
        // Additional integrity checks or performance improvements could be done elsewhere,
        // such as validating data on appear or logging errors with os_log.
    }
    
    // Separate view content for each movie row to keep things clear and maintainable.
    private func rowContent(for movie: Movie) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                if editingMovie?.id == movie.id {
                    TextField("Title", text: $editedTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .accessibilityLabel("Edit movie title")
                    
                    TextField("Link (URL)", text: $editedLink)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .accessibilityLabel("Edit movie link")
                    
                    Picker("Source", selection: $editedType) {
                        Text("CinemaInformation").tag(MovieSource.cinema)
                        Text("Platform").tag(MovieSource.platform)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .accessibilityLabel("Choose movie source")
                    
                } else {
                    Text(movie.title)
                        .font(.headline)
                        .accessibilityLabel("\(movie.title), \(movie.source.rawValue)")
                    
                    Text(movie.source.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                if editingMovie?.id == movie.id {
                    Button(action: { saveEditedMovie(movie) }) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .imageScale(.large)
                            .accessibilityLabel("Save changes")
                    }
                    
                    Button(action: cancelEditing) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .imageScale(.large)
                            .accessibilityLabel("Cancel editing")
                    }
                } else {
                    Button(action: { startEditing(movie) }) {
                        Image(systemName: "pencil.circle")
                            .foregroundColor(.blue) // Ensure suitable color for both modes
                            .imageScale(.large)
                            .accessibilityLabel("Edit movie details")
                    }
                    
                    Button(action: {
                        movieToDelete = movie
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .imageScale(.large)
                            .accessibilityLabel("Delete this movie")
                    }
                }
            }
        }
    }
    
    private var addMovieSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Movie Details")) {
                    TextField("Movie Title", text: $newMovieTitle)
                        .accessibilityLabel("New movie title")
                    
                    TextField("Movie Link (URL)", text: $newMovieLink)
                        .accessibilityLabel("New movie link")
                    
                    Picker("Movie Source", selection: $selectedType) {
                        Text("Select a source").tag(nil as MovieSource?)
                        Text("CinemaInformation").tag(MovieSource.cinema)
                        Text("Platform").tag(MovieSource.platform)
                    }
                    .accessibilityLabel("Source for the new movie")
                }
            }
            .navigationTitle("Add Movie")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetAddMovieFields()
                    }
                    .accessibilityLabel("Cancel adding movie")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addMovie()
                    }
                    .disabled(newMovieTitle.isEmpty || newMovieLink.isEmpty || selectedType == nil)
                    .accessibilityLabel("Confirm adding new movie")
                }
            }
        }
    }
    
    private func addMovie() {
        guard !newMovieTitle.isEmpty,
              !newMovieLink.isEmpty,
              let type = selectedType,
              isValidURL(newMovieLink) else {
            showInvalidURLAlert = true
            return
        }
        
        let movie = Movie(
            id: UUID(),
            title: newMovieTitle,
            cinema: CinemaInformation(id: UUID(), name: "Default Cinema", location: "Unknown"),
            source: type,
            posterImage: newMovieLink,
            releaseDate: nil
        )
        
        // Logging selected type for debugging purposes.
        os_log("Added movie with source: %{public}@", log: .default, type: .debug, type.rawValue)
        
        movieDatabase.addMovie(movie)
        resetAddMovieFields()
    }
    
    private func resetAddMovieFields() {
        newMovieTitle = ""
        newMovieLink = ""
        selectedType = nil
        isAddingMovie = false
    }
    
    private func startEditing(_ movie: Movie) {
        editingMovie = movie
        editedTitle = movie.title
        editedLink = movie.posterImage ?? ""
        editedType = movie.source
    }
    
    private func cancelEditing() {
        editingMovie = nil
        editedTitle = ""
        editedLink = ""
        editedType = nil
    }
    
    private func saveEditedMovie(_ originalMovie: Movie) {
        guard !editedTitle.isEmpty,
              !editedLink.isEmpty,
              let newType = editedType,
              isValidURL(editedLink) else {
            showInvalidURLAlert = true
            return
        }
        
        let updatedMovie = Movie(
            id: originalMovie.id,
            title: editedTitle,
            cinema: originalMovie.cinema,
            source: newType,
            posterImage: editedLink,
            releaseDate: originalMovie.releaseDate
        )
        
        movieDatabase.updateMovie(updatedMovie)
        cancelEditing()
    }
    
    private func confirmDelete(at offsets: IndexSet) {
        // This could be adapted if needed. Currently using a confirmation alert instead.
        // If you want direct deletion without confirmation, uncomment the line below:
        // movieDatabase.movies.remove(atOffsets: offsets)
    }
    
    private func isValidURL(_ urlString: String) -> Bool {
        // Checking URL integrity before attempting to open it.
        guard let url = URL(string: urlString) else {
            return false
        }
        return UIApplication.shared.canOpenURL(url)
    }
}
