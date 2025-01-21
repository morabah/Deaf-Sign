import SwiftUI
import os.log
import FirebaseCore
import FirebaseAuth
//note
struct ContentView: View {
    @EnvironmentObject var movieDatabase: MovieDatabase
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var showCinemaView = false
    @State private var showPlatformView = false
    @State private var searchDebounceTimer: Timer?
    @FocusState private var isInputActive: Bool
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSignedOut = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Top Bar
                            topBar
                            
                            // Search Bar
                            searchBar
                            
                            // Search Results
                            if !searchText.isEmpty {
                                searchResultsView
                            }
                            
                            // Movie Source Buttons
                            HStack(spacing: 20) {
                                sourceButton(title: "Cinema", systemImage: "film", action: { showCinemaView = true })
                                sourceButton(title: "Platform", systemImage: "tv", action: { showPlatformView = true })
                            }
                            .padding(.horizontal, 20)
                            
                            // Recent Movies Section
                            recentMoviesView
                        }
                        .padding(.vertical, 20)
                    }
                    
                    // Sign Out Button at the bottom
                    Button(action: handleSignOut) {
                        Text("Sign Out")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 50)
                    .padding(.vertical, 20)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $isSignedOut) {
                LoginView()
                    .environmentObject(authManager)
            }
        }
        .onChange(of: movieDatabase.error != nil, initial: true) { oldValue, newValue in
            if newValue, let error = movieDatabase.error {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showCinemaView) {
            CinemaView()
                .environmentObject(movieDatabase)
        }
        .sheet(isPresented: $showPlatformView) {
            PlatformView()
                .environmentObject(movieDatabase)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(movieDatabase)
        }
        .onAppear {
            Logger.log("ContentView appeared", level: .debug)
            verifyDataIntegrity()
        }
    }
    
    // MARK: - Subviews
    
    private var topBar: some View {
        VStack(spacing: 8) {
            // Welcome message
            if let userName = authManager.currentUser?.displayName ?? authManager.currentUser?.email {
                Text("Hi, \(userName)!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            
            HStack {
                Text("📦 Nuby")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    Logger.log("Settings button pressed", level: .debug)
                    showSettings = true
                }) {
                    Image(systemName: "gear")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
        }
        .padding(.top)
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
                .onChange(of: searchText) { _, newValue in
                    // Immediate filtering for better responsiveness
                    performSearch(query: newValue)
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
            
            let filteredMovies = movieDatabase.searchMovies(query: searchText)
            
            if filteredMovies.isEmpty {
                Text("No movies found")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredMovies) { movie in
                            NavigationLink(destination: TimelineCaptureView(movie: movie)) {
                                MovieRow(movie: movie)
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var recentMoviesView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last 5 Added Movies")
                .font(.headline)
                .padding(.horizontal)
            
            let recentMovies = movieDatabase.movies.prefix(5)
            if recentMovies.isEmpty {
                Text("No recently added movies")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 15) {
                        ForEach(recentMovies) { movie in
                            NavigationLink(destination: TimelineCaptureView(movie: movie)) {
                                MoviePosterView(movie: movie)
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
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Actions
    
    private func handleSignOut() {
        Logger.log("User attempting to sign out", level: .debug)
        do {
            try Auth.auth().signOut()
            try authManager.signOut()
            isSignedOut = true
            Logger.log("User successfully signed out", level: .debug)
        } catch {
            Logger.log("Error signing out: \(error.localizedDescription)", level: .error)
            alertMessage = "Failed to sign out: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    // MARK: - Helper Methods
    
    private func performSearch(query: String) {
        // Perform the search immediately for better responsiveness
        let filteredMovies = movieDatabase.searchMovies(query: query)
        Logger.log("Search performed with query: '\(query)'. Found \(filteredMovies.count) matching titles", level: .debug)
    }
    
    private func verifyDataIntegrity() {
        Logger.log("Verifying data integrity", level: .debug)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MovieDatabase())
            .environmentObject(AuthenticationManager())
    }
}
