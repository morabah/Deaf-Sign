//
//  NubyApp.swift
//  Nuby
//
//  Created by Mohamed Rabah on 05/12/2024.
//

import SwiftUI
import Foundation
import GoogleSignIn
import FirebaseCore
import FirebaseAuth
import FirebaseAppCheck
import os.log
import UIKit

// App Delegate to handle Firebase configuration


/// The main application struct for the Nuby app
/// Responsible for setting up the initial app state and environment
@main
struct NubyApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    /// Manages the movie database across the entire application
    @StateObject private var movieDatabase = MovieDatabase()
    
    /// Manages authentication across the entire application
    @StateObject private var authManager = AuthenticationManager.shared
    
    /// State for showing onboarding
    @State private var showingOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    init() {
        // Configure appearance
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            // Log app launch
            let _ = Logger.log("Nuby app launched", level: .info)
            
            Group {
                if authManager.isAuthenticated {
                    if showingOnboarding {
                        OnboardingView(isPresented: $showingOnboarding)
                            .environmentObject(movieDatabase)
                            .environmentObject(authManager)
                    } else {
                        ContentView()
                            .environmentObject(movieDatabase)
                            .environmentObject(authManager)
                    }
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
            .onAppear {
                // Configure app on first launch
                configureGoogleSignIn()
            }
        }
    }
    
    private func configureGoogleSignIn() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            Logger.log("Failed to get Firebase client ID", level: .error)
            return
        }
        
        // Configure Google Sign In
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        // Check for existing sign-in
        Task { @MainActor in
            do {
                if let user = try? await GIDSignIn.sharedInstance.restorePreviousSignIn() {
                    let credential = GoogleAuthProvider.credential(
                        withIDToken: user.idToken?.tokenString ?? "",
                        accessToken: user.accessToken.tokenString
                    )
                    
                    let result = try await Auth.auth().signIn(with: credential)
                    authManager.isAuthenticated = true
                    Logger.log("Successfully restored Google Sign-In session", level: .info)
                }
            } catch {
                Logger.log("Failed to sign in with Google: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = .systemBackground
        
        // Apply the appearance settings
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .systemBackground
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Set the App Check debug provider factory
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)

        // Configure Firebase
        FirebaseApp.configure()

        return true
    }
}
func logDebugToken() {
    AppCheck.appCheck().token(forcingRefresh: true) { token, error in
        if let error = error {
            print("Error fetching debug token: \(error.localizedDescription)")
            return
        }
        
        if let token = token {
            print("Debug Token: \(token.token)")
        }
    }
}
// Handle Google Sign-In URL
   func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
       return GIDSignIn.sharedInstance.handle(url)
   }

