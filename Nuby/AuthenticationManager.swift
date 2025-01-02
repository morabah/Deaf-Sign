import Foundation
import GoogleSignIn
import os.log

enum AuthError: LocalizedError, Equatable {
    case googleSignInFailed(String)
    case noRootViewController
    case noResult
    
    var errorDescription: String? {
        switch self {
        case .googleSignInFailed(let message):
            return "Google Sign-In failed: \(message)"
        case .noRootViewController:
            return "No root view controller found"
        case .noResult:
            return "No result from Google Sign-In"
        }
    }
    
    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.googleSignInFailed(let lhsMessage), .googleSignInFailed(let rhsMessage)):
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

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: GIDGoogleUser?
    @Published var authError: AuthError?
    
    static let shared = AuthenticationManager()
    
    private init() {
        // Check for existing sign-in
        if let user = GIDSignIn.sharedInstance.currentUser {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            Logger.log("No root view controller found", level: .error)
            self.authError = .noRootViewController
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            if let error = error {
                Logger.log("Google Sign-In error: \(error.localizedDescription)", level: .error)
                self?.authError = .googleSignInFailed(error.localizedDescription)
                return
            }
            
            guard let result = result else {
                Logger.log("No result from Google Sign-In", level: .error)
                self?.authError = .noResult
                return
            }
            
            self?.currentUser = result.user
            self?.isAuthenticated = true
            Logger.log("Successfully signed in with Google", level: .info)
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        currentUser = nil
        isAuthenticated = false
        Logger.log("Signed out from Google", level: .info)
    }
}
