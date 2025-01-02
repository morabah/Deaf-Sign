//
//  NubyApp.swift
//  Nuby
//
//  Created by Mohamed Rabah on 05/12/2024.
//

import SwiftUI
import Foundation
import GoogleSignIn

/// The main application struct for the Nuby app
/// Responsible for setting up the initial app state and environment
@main
struct NubyApp: App {
    /// Manages the movie database across the entire application
    @StateObject private var movieDatabase = MovieDatabase()
    
    /// Manages authentication across the entire application
    @StateObject private var authManager = AuthenticationManager.shared
    
    /// State for showing onboarding
    @State private var showingOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    /// The main scene of the application
    /// Configures the initial view and provides app-wide environment objects
    var body: some Scene {
        WindowGroup {
            // Log app launch
            let _ = Logger.log("Nuby app launched", level: .info)
            
            Group {
                if authManager.isAuthenticated {
                    if showingOnboarding {
                        OnboardingView(isPresented: $showingOnboarding)
                            .environmentObject(movieDatabase)
                    } else {
                        ContentView()
                            .environmentObject(movieDatabase)
                    }
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
            .onAppear {
                // Additional logging for app initialization
                Logger.log("Initializing app components", level: .debug)
            }
        }
    }
    
    /// Initializer for the app
    /// Can be used for any global setup or configuration
    init() {
        // Configure any global settings or perform initial setup
        configureAppearance()
        
        // Configure Google Sign-In
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            Logger.log("Failed to get Google Sign-In client ID", level: .error)
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }
    
    /// Configures the global appearance of the app
    private func configureAppearance() {
        // Log appearance configuration
        Logger.log("Configuring app appearance", level: .debug)
        
        // Example: Set a global accent color or other UI configurations
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]
    }
}
