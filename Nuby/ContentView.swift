import SwiftUI
import os.log

struct ContentView: View {
    @EnvironmentObject var movieDatabase: MovieDatabase
    @EnvironmentObject var authManager: AuthenticationManager
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
                    
                    // Movie Source Buttons
                    HStack(spacing: padding) {
                        sourceButton(
                            title: "Cinema",
                            systemImage: "film",
                            action: { showCinemaView = true }
                        )
                        
                        sourceButton(
                            title: "Platform",
                            systemImage: "tv",
                            action: { showPlatformView = true }
                        )
                    }
                    
                    // Last 5 Added Movies
                    recentMoviesView
                    
                    Spacer()
                }
                .padding(.bottom)
            }
            .navigationBarItems(trailing: settingsButton)
            .navigationBarHidden(false)
            .sheet(isPresented: $showSettings) {
                SettingsView(movieDatabase: movieDatabase)
            }
            .sheet(isPresented: $showCinemaView) {
                CinemaView()
                    .environmentObject(movieDatabase)
            }
            .sheet(isPresented: $showPlatformView) {
                PlatformView()
                    .environmentObject(movieDatabase)
            }
        }
        .onAppear {
            Logger.log("ContentView appeared", level: .debug)
            verifyDataIntegrity()
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Button(action: {
                Logger.log("Settings button pressed", level: .debug)
                showSettings = true
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

    private func sourceButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .imageScale(.large)
                
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(buttonOpacity))
            .cornerRadius(cornerRadius)
        }
    }

    private var settingsButton: some View {
        HStack {
            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
                    .imageScale(.large)
            }
            
            Button(action: { authManager.signOut() }) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .imageScale(.large)
            }
        }
    }

    // MARK: - Helper Methods

    private func performSearch(query: String) {
        Logger.log("Performing search for: \(query)", level: .debug)
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    }

    private func verifyDataIntegrity() {
        Logger.log("Verifying data integrity", level: .debug)
        // Add data validation logic here
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MovieDatabase())
            .environmentObject(AuthenticationManager.shared)
    }
}
