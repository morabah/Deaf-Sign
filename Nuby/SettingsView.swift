import SwiftUI
import os.log
import UIKit

/// Main settings view for managing movie library and app preferences
struct SettingsView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State Objects
    @StateObject private var movieManager: MovieManager
    
    // MARK: - State
    @State private var editingMovie: Movie?
    @State private var isAddingMovie = false
    @State private var showDeleteConfirmation = false
    @State private var movieToDelete: Movie?
    @State private var showSuccessToast = false
    @State private var toastMessage = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    // MARK: - Initialization
    init(movieDatabase: MovieDatabase? = nil) {
        let db = movieDatabase ?? MovieDatabase()
        _movieManager = StateObject(wrappedValue: MovieManager(movieDatabase: db))
    }
    
    // MARK: - Computed Properties
    private var filteredMovies: [Movie] {
        movieManager.filteredMovies
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Movie Library")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .sheet(item: $editingMovie, content: editMovieSheet)
                .sheet(isPresented: $isAddingMovie, content: addMovieSheet)
                .confirmationDialog(
                    "Delete Movie",
                    isPresented: $showDeleteConfirmation,
                    presenting: movieToDelete,
                    actions: deleteConfirmationActions,
                    message: deleteConfirmationMessage
                )
        }
    }
    
    // MARK: - View Components
    private var mainContent: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .edgesIgnoringSafeArea(.all)
            
            // Content Stack
            VStack(spacing: 0) {
                searchBar
                movieList
                addButton
            }
            
            // Toasts
            if showSuccessToast {
                successToast
            }
            if showError {
                errorToast
            }
        }
    }
    
    private var searchBar: some View {
        SearchBar(
            searchText: $movieManager.searchText,
            movieManager: movieManager
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var movieList: some View {
        List {
            ForEach(filteredMovies) { movie in
                MovieCardView(movie: movie)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        deleteButton(for: movie)
                        editButton(for: movie)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
    }
    
    private var addButton: some View {
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
    
    private var successToast: some View {
        ToastView(message: toastMessage, style: .success)
            .transition(.move(edge: .top))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showSuccessToast = false
                    }
                }
            }
    }
    
    private var errorToast: some View {
        ToastView(message: errorMessage, style: .error)
            .transition(.move(edge: .top))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showError = false
                    }
                }
            }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Action Buttons
    private func deleteButton(for movie: Movie) -> some View {
        Button(role: .destructive) {
            movieToDelete = movie
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash.fill")
        }
    }
    
    private func editButton(for movie: Movie) -> some View {
        Button {
            editingMovie = movie
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .tint(.blue)
    }
    
    // MARK: - Sheet Content
    private func editMovieSheet(movie: Movie) -> some View {
        MovieEditSheet(
            movie: movie,
            onSave: { updatedMovie in
                Task {
                    do {
                        try await movieManager.updateMovie(updatedMovie)
                        withAnimation {
                            toastMessage = "Movie updated successfully!"
                            showSuccessToast = true
                            editingMovie = nil
                        }
                    } catch {
                        withAnimation {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
            },
            onCancel: {
                editingMovie = nil
            }
        )
    }
    
    private func addMovieSheet() -> some View {
        MovieAddSheet(
            onSave: { newMovie in
                Task {
                    do {
                        try await movieManager.addMovie(newMovie)
                        withAnimation {
                            toastMessage = "Movie added successfully!"
                            showSuccessToast = true
                            isAddingMovie = false
                        }
                    } catch {
                        withAnimation {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
            },
            onCancel: {
                isAddingMovie = false
            }
        )
    }
    
    // MARK: - Delete Confirmation
    private func deleteConfirmationActions(for movie: Movie) -> some View {
        Button("Delete", role: .destructive) {
            Task {
                do {
                    try await movieManager.deleteMovie(movie)
                    withAnimation {
                        toastMessage = "Movie deleted successfully!"
                        showSuccessToast = true
                    }
                } catch {
                    withAnimation {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }
    
    private func deleteConfirmationMessage(for movie: Movie) -> some View {
        Text("Are you sure you want to delete '\(movie.title)'?")
    }
}

// MARK: - Supporting Views
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

struct ToastView: View {
    let message: String
    let style: ToastStyle
    
    enum ToastStyle {
        case success
        case error
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            }
        }
    }
    
    var body: some View {
        Text(message)
            .font(.subheadline)
            .padding()
            .background(style.color)
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.top, 16)
    }
}

// MARK: - Sheets
struct MovieAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Movie) -> Void
    let onCancel: () -> Void
    
    @State private var title = ""
    @State private var link = ""
    @State private var source = MovieSource.cinema
    @State private var cinemaName = ""
    @State private var cinemaLocation = ""
    @State private var releaseDate = Date()
    @State private var isLoading = false
    @State private var hasYouTubeInClipboard = false
    
    private func checkClipboardForYouTubeLink() {
        if let clipboardString = UIPasteboard.general.string,
           let url = URL(string: clipboardString),
           TimelineCaptureView.isYouTubeURL(url) {
            hasYouTubeInClipboard = true
        } else {
            hasYouTubeInClipboard = false
        }
    }
    
    private func pasteFromClipboard() {
        if let clipboardString = UIPasteboard.general.string,
           let url = URL(string: clipboardString),
           TimelineCaptureView.isYouTubeURL(url) {
            link = clipboardString
        }
    }
    
    // URL validation helper
    private func validateAndFormatURL(_ urlString: String) -> String {
        var formattedString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If empty string, return as is
        if formattedString.isEmpty {
            return formattedString
        }
        
        // If URL doesn't start with a protocol, add https://
        if !formattedString.lowercased().hasPrefix("http") {
            formattedString = "https://" + formattedString
        }
        
        // If URL starts with http://, replace with https://
        if formattedString.lowercased().hasPrefix("http://") {
            formattedString = "https://" + formattedString.dropFirst("http://".count)
        }
        
        // If URL doesn't have www. after https://, add it
        if formattedString.lowercased().hasPrefix("https://") && !formattedString.lowercased().hasPrefix("https://www.") {
            formattedString = formattedString.replacingOccurrences(of: "https://", with: "https://www.")
        }
        
        return formattedString
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Movie Details")) {
                    TextField("Title", text: $title)
                    HStack {
                        TextField("Link", text: $link)
                            .onChange(of: link) { oldValue, newValue in
                                link = validateAndFormatURL(newValue)
                            }
                            .onAppear {
                                checkClipboardForYouTubeLink()
                            }
                        if hasYouTubeInClipboard {
                            Button(action: pasteFromClipboard) {
                                Image(systemName: "doc.on.clipboard")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    Picker("Source", selection: $source) {
                        Text("Cinema").tag(MovieSource.cinema)
                        Text("Platform").tag(MovieSource.platform)
                    }
                    DatePicker("Release Date", selection: $releaseDate, displayedComponents: .date)
                }
                
                if source == .cinema {
                    Section(header: Text("Cinema Information")) {
                        TextField("Cinema Name", text: $cinemaName)
                        TextField("Location", text: $cinemaLocation)
                    }
                }
            }
            .navigationTitle("Add Movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMovie()
                    }
                    .disabled(!isValid)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
    
    private var isValid: Bool {
        !title.isEmpty && (!link.isEmpty || source == .cinema) &&
        (source != .cinema || (!cinemaName.isEmpty && !cinemaLocation.isEmpty))
    }
    
    private func saveMovie() {
        let cinema = CinemaInformation(
            id: UUID(),
            name: cinemaName,
            location: cinemaLocation
        )
        
        let movie = Movie(
            id: UUID(),
            firestoreId: "",
            title: title,
            cinema: cinema,
            source: source,
            posterImage: link.isEmpty ? nil : link,
            releaseDate: releaseDate,
            userId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        onSave(movie)
    }
}

struct MovieEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let movie: Movie
    let onSave: (Movie) -> Void
    let onCancel: () -> Void
    
    @State private var title: String
    @State private var link: String
    @State private var source: MovieSource
    @State private var cinemaName: String
    @State private var cinemaLocation: String
    @State private var releaseDate: Date
    @State private var isLoading = false
    @State private var hasYouTubeInClipboard = false
    
    private func checkClipboardForYouTubeLink() {
        if let clipboardString = UIPasteboard.general.string,
           let url = URL(string: clipboardString),
           TimelineCaptureView.isYouTubeURL(url) {
            hasYouTubeInClipboard = true
        } else {
            hasYouTubeInClipboard = false
        }
    }
    
    private func pasteFromClipboard() {
        if let clipboardString = UIPasteboard.general.string,
           let url = URL(string: clipboardString),
           TimelineCaptureView.isYouTubeURL(url) {
            link = clipboardString
        }
    }
    
    init(movie: Movie, onSave: @escaping (Movie) -> Void, onCancel: @escaping () -> Void) {
        self.movie = movie
        self.onSave = onSave
        self.onCancel = onCancel
        
        _title = State(initialValue: movie.title)
        _link = State(initialValue: movie.posterImage ?? "")
        _source = State(initialValue: movie.source)
        _cinemaName = State(initialValue: movie.cinema.name)
        _cinemaLocation = State(initialValue: movie.cinema.location)
        _releaseDate = State(initialValue: movie.releaseDate ?? Date())
    }
    
    // URL validation helper
    private func validateAndFormatURL(_ urlString: String) -> String {
        var formattedString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If empty string, return as is
        if formattedString.isEmpty {
            return formattedString
        }
        
        // If URL doesn't start with a protocol, add https://
        if !formattedString.lowercased().hasPrefix("http") {
            formattedString = "https://" + formattedString
        }
        
        // If URL starts with http://, replace with https://
        if formattedString.lowercased().hasPrefix("http://") {
            formattedString = "https://" + formattedString.dropFirst("http://".count)
        }
        
        // If URL doesn't have www. after https://, add it
        if formattedString.lowercased().hasPrefix("https://") && !formattedString.lowercased().hasPrefix("https://www.") {
            formattedString = formattedString.replacingOccurrences(of: "https://", with: "https://www.")
        }
        
        return formattedString
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Movie Details")) {
                    TextField("Title", text: $title)
                    HStack {
                        TextField("Link", text: $link)
                            .onChange(of: link) { oldValue, newValue in
                                link = validateAndFormatURL(newValue)
                            }
                            .onAppear {
                                checkClipboardForYouTubeLink()
                            }
                        if hasYouTubeInClipboard {
                            Button(action: pasteFromClipboard) {
                                Image(systemName: "doc.on.clipboard")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    Picker("Source", selection: $source) {
                        Text("Cinema").tag(MovieSource.cinema)
                        Text("Platform").tag(MovieSource.platform)
                    }
                    DatePicker("Release Date", selection: $releaseDate, displayedComponents: .date)
                }
                
                if source == .cinema {
                    Section(header: Text("Cinema Information")) {
                        TextField("Cinema Name", text: $cinemaName)
                        TextField("Location", text: $cinemaLocation)
                    }
                }
            }
            .navigationTitle("Edit Movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
    
    private var isValid: Bool {
        !title.isEmpty && (!link.isEmpty || source == .cinema) &&
        (source != .cinema || (!cinemaName.isEmpty && !cinemaLocation.isEmpty))
    }
    
    private func saveChanges() {
        let cinema = CinemaInformation(
            id: movie.cinema.id,
            name: cinemaName,
            location: cinemaLocation
        )
        
        let updatedMovie = Movie(
            id: movie.id,
            firestoreId: movie.firestoreId,
            title: title,
            cinema: cinema,
            source: source,
            posterImage: link.isEmpty ? nil : link,
            releaseDate: releaseDate,
            userId: movie.userId,
            createdAt: movie.createdAt,
            updatedAt: Date()
        )
        
        onSave(updatedMovie)
    }
}
