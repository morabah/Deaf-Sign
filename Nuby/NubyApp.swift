//
//  NubyApp.swift
//  Nuby
//
//  Created by Mohamed Rabah on 05/12/2024.
//

import SwiftUI
import Foundation

/// The main application struct for the Nuby app
/// Responsible for setting up the initial app state and environment
@main
struct NubyApp: App {
    /// Manages the movie database across the entire application
    @StateObject private var movieDatabase = MovieDatabase()
    
    /// State for showing onboarding
    @State private var showingOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    /// The main scene of the application
    /// Configures the initial view and provides app-wide environment objects
    var body: some Scene {
        WindowGroup {
            // Log app launch
            let _ = Logger.log("Nuby app launched", level: .info)
            
            // Initial view with shared movie database
            if showingOnboarding {
                OnboardingView(isPresented: $showingOnboarding)
                    .environmentObject(movieDatabase)
                    .onAppear {
                        // Additional logging for app initialization
                        Logger.log("Initializing movie database", level: .debug)
                    }
            } else {
                ContentView()
                    .environmentObject(movieDatabase)
            }
        }
    }
    
    /// Initializer for the app
    /// Can be used for any global setup or configuration
    init() {
        // Configure any global settings or perform initial setup
        configureAppearance()
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
