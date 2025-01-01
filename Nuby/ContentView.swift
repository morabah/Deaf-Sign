import SwiftUI
import os.log

struct ContentView: View {
    @StateObject private var movieDatabase = MovieDatabase()
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var showCinemaView = false
    @State private var showPlatformView = false
    @State private var searchDebounceTimer: Timer?
    @FocusState private var isInputActive: Bool

    // Constants
    private let cornerRadius: CGFloat = 8
    private let padding: CGFloat = 16
    private let buttonOpacity: Double = 0.1

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: padding) {
                    // Top Bar
                    topBar
                    
                    // Section Title
                    sectionTitle("Choose Movie Source")
                    
                    // Search Bar
                    searchBar
                    
                    // Search Results
                    if !searchText.isEmpty {
                        searchResultsView
                    }
                    
                    // Source Buttons
                    sourceButtons
                    
                    // Last 5 Added Movies
                    recentMoviesView
                    
                    Spacer()
                }
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            verifyDataIntegrity()
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Button(action: {
                showSettings = true
                os_log("Settings button pressed", log: .default, type: .debug)
            }) {
                Image(systemName: "gear")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(buttonOpacity))
                    .clipShape(Circle())
                    .accessibilityLabel("Open Settings")
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(movieDatabase: movieDatabase)
            }
            
            Spacer()
            
            Text("📦 Nuby")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityLabel("App title: Nuby")
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(buttonOpacity))
            .cornerRadius(cornerRadius)
            .accessibilityAddTraits(.isHeader)
    }

    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            TextField("Search Movies", text: $searchText)
                .focused($isInputActive)
                .onSubmit {
                    performSearch(query: searchText)
                }
                .onChange(of: searchText) { newValue in
                    searchDebounceTimer?.invalidate()
                    searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                        performSearch(query: newValue)
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
        }
        .padding(.top, 10)
    }

    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search Results")
                .font(.headline)
                .padding(.horizontal)
            
            let searchResults = movieDatabase.searchMovies(query: searchText)
            if searchResults.isEmpty {
                Text("No movies found")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 15) {
                        ForEach(searchResults) { movie in
                            NavigationLink(destination: TimelineCaptureView(movie: movie)) {
                                Text(movie.title)
                                    .padding(8)
                                    .background(Color.blue.opacity(buttonOpacity))
                                    .cornerRadius(cornerRadius)
                                    .foregroundColor(.primary)
                                    .accessibilityLabel("Movie: \(movie.title)")
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 10)
            }
        }
        .transition(.opacity)
    }

    private var sourceButtons: some View {
        VStack(spacing: 15) {
            Button(action: {
                os_log("Cinema source button pressed", log: .default, type: .debug)
                showCinemaView = true
            }) {
                Text("Cinema")
                    .font(.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(buttonOpacity))
                    .cornerRadius(cornerRadius)
                    .accessibilityLabel("Open Cinema View")
            }
            .sheet(isPresented: $showCinemaView) {
                CinemaView()
                    .environmentObject(movieDatabase)
            }
            
            Button(action: {
                os_log("Platform source button pressed", log: .default, type: .debug)
                showPlatformView = true
            }) {
                Text("Platform")
                    .font(.body)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(buttonOpacity))
                    .cornerRadius(cornerRadius)
                    .accessibilityLabel("Open Platform View")
            }
            .sheet(isPresented: $showPlatformView) {
                PlatformView()
                    .environmentObject(movieDatabase)
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }

    private var recentMoviesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last 5 Added Movies")
                .font(.headline)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
            
            let recentMovies = movieDatabase.movies.prefix(5)
            if recentMovies.isEmpty {
                Text("No recently added movies available.")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 15) {
                        ForEach(recentMovies) { movie in
                            NavigationLink(destination: TimelineCaptureView(movie: movie)) {
                                MoviePosterView(movie: movie)
                                    .accessibilityLabel("Open details for \(movie.title)")
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Helper Methods

    private func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        os_log("Performing search for: %@", log: .default, type: .debug, query)
    }

    private func verifyDataIntegrity() {
        os_log("Verifying data integrity", log: .default, type: .debug)
        // Add data validation logic here
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
