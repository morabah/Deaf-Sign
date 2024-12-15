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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Top Bar with Settings and App Name
                    HStack {
                        Button(action: {
                            showSettings = true
                            os_log("Settings button pressed in ContentView", log: .default, type: .debug)
                        }) {
                            Image(systemName: "gear")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.blue)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
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
                    
                    // Section Title
                    Text("Choose Movie Source")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .accessibilityAddTraits(.isHeader)
                    
                    // Search Bar
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
                    
                    // Display Search Results if present
                    if !searchText.isEmpty {
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
                                    HStack(spacing: 15) {
                                        ForEach(searchResults) { movie in
                                            NavigationLink(destination: TimelineCaptureView(movie: movie)) {
                                                Text(movie.title)
                                                    .padding(8)
                                                    .background(Color.blue.opacity(0.1))
                                                    .cornerRadius(5)
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
                    
                    // Source Buttons
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
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
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
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .accessibilityLabel("Open Platform View")
                        }
                        .sheet(isPresented: $showPlatformView) {
                            PlatformView()
                                .environmentObject(movieDatabase)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Last 5 Added Movies
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
                                HStack(spacing: 15) {
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
                    
                    Spacer()
                }
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Verify data integrity or handle initial data load checks
            verifyDataIntegrity()
        }
    }
    
    // Improved search logic placeholder
    private func performSearch(query: String) {
        // Confirm that the query is sensible before searching
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        // Additional data checks or integrity validations can be added here as needed.
        // Search operation already handled by movieDatabase.searchMovies(query:).
        // Could add logging or error checks if search fails or returns empty unexpectedly.
    }
    
    // Basic data integrity check placeholder
    private func verifyDataIntegrity() {
        // Example: If the database fails to load or contains invalid data, handle it
        // For now, we assume the data is valid. In a real scenario, add checks here.
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
