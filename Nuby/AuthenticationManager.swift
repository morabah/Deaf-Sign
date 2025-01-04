import Foundation
import GoogleSignIn
import FirebaseAuth
import FirebaseCore
import FirebaseAnalytics
import SwiftUI
import os.log

enum AuthError: LocalizedError, Equatable {
    case googleSignInFailed(String)
    case emailSignInFailed(String)
    case noRootViewController
    case noResult
    
    var errorDescription: String? {
        switch self {
        case .googleSignInFailed(let message):
            return "Google Sign-In failed: \(message)"
        case .emailSignInFailed(let message):
            return "Email Sign-In failed: \(message)"
        case .noRootViewController:
            return "No root view controller found"
        case .noResult:
            return "No result from Sign-In"
        }
    }
    
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.googleSignInFailed(let lhsMessage), .googleSignInFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.emailSignInFailed(let lhsMessage), .emailSignInFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.noRootViewController, .noRootViewController):
            return true
        case (.noResult, .noResult):
            return true
        default:
            return false
        }
    }
}

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var authError: AuthError?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    static let shared = AuthenticationManager()
    
    init() {
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            self?.currentUser = user
            self?.isAuthenticated = user != nil
            
            if let user = user {
                Analytics.logEvent(AnalyticsEventLogin, parameters: [
                    AnalyticsParameterMethod: "email",
                    "user_id": user.uid
                ])
            }
        }
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    func signInWithEmail(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.currentUser = result.user
            self.isAuthenticated = true
        } catch {
            self.authError = .emailSignInFailed(error.localizedDescription)
            throw error
        }
    }
    
    func signUpWithEmail(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.currentUser = result.user
            self.isAuthenticated = true
            
            Analytics.logEvent(AnalyticsEventSignUp, parameters: [
                AnalyticsParameterMethod: "email",
                "user_id": result.user.uid
            ])
        } catch {
            self.authError = .emailSignInFailed(error.localizedDescription)
            throw error
        }
    }
    
    func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            self.authError = .noRootViewController
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            if let error = error {
                self?.authError = .googleSignInFailed(error.localizedDescription)
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                self?.authError = .noResult
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            Task { @MainActor in
                do {
                    let result = try await Auth.auth().signIn(with: credential)
                    self?.currentUser = result.user
                    self?.isAuthenticated = true
                    
                    Analytics.logEvent(AnalyticsEventLogin, parameters: [
                        AnalyticsParameterMethod: "google",
                        "user_id": result.user.uid
                    ])
                } catch {
                    self?.authError = .googleSignInFailed(error.localizedDescription)
                }
            }
        }
    }
    
    func signOut() throws {
        let uid = currentUser?.uid
        try Auth.auth().signOut()
        self.currentUser = nil
        self.isAuthenticated = false
        
        Analytics.logEvent("user_logout", parameters: [
            "user_id": uid ?? "unknown"
        ])
    }
}
