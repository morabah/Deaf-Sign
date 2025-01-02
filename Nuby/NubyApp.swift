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
                // Configure app on first launch
                configureGoogleSignIn()
                configureAppearance()
            }
        }
    }
    
    private func configureGoogleSignIn() {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            Logger.log("Failed to get Google Sign-In client ID", level: .error)
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            if let user = user {
                DispatchQueue.main.async {
                    AuthenticationManager.shared.currentUser = user
                    AuthenticationManager.shared.isAuthenticated = true
                    Logger.log("Restored previous Google Sign-In session", level: .info)
                }
            } else if let error = error {
                Logger.log("Failed to restore Google Sign-In: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    private func configureAppearance() {
        Logger.log("Configuring app appearance", level: .debug)
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]
    }
}
