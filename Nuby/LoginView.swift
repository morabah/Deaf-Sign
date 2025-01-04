import SwiftUI
import GoogleSignIn
import os.log

struct LoginView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSigningUp = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Gradient
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // App Logo
                    Image(systemName: "film.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.white)
                        .padding(.top, 50)
                    
                    // Welcome Message
                    Text("Welcome to Nuby")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Login Form
                    VStack(spacing: 15) {
                        TextField("Email", text: $email)
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: email, initial: true) { oldValue, newValue in
                                validateEmail(newValue)
                            }
                        
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                            .onChange(of: password, initial: true) { oldValue, newValue in
                                validatePassword(newValue)
                            }
                        
                        Button(action: handleLogin) {
                            Text("Sign In")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                                .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 30)
                    
                    // Divider with "or"
                    HStack {
                        VStack { Divider().background(Color.white) }
                        Text("or")
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                        VStack { Divider().background(Color.white) }
                    }
                    .padding(.horizontal, 30)
                    
                    // Google Sign In Button
                    Button(action: {
                        authManager.signInWithGoogle()
                    }) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .foregroundColor(.red)
                            Text("Sign in with Google")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    }
                    .padding(.horizontal, 30)
                    
                    // Sign Up Link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.white)
                        Button(action: { isSigningUp = true }) {
                            Text("Sign Up")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                        }
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    Logger.log("Login cancelled", level: .debug)
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Login Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $isSigningUp) {
                SignUpView()
                    .environmentObject(authManager)
            }
            .onChange(of: authManager.isAuthenticated, initial: true) { oldValue, newValue in
                handleAuthenticationChange(newValue)
            }
            .onChange(of: authManager.authError, initial: true) { oldValue, newValue in
                handleAuthError(newValue)
            }
        }
        .onAppear {
            Logger.log("LoginView appeared", level: .debug)
        }
    }
    
    private func handleLogin() {
        Logger.log("Attempting login for email: \(email)", level: .debug)
        
        Task {
            do {
                try await authManager.signInWithEmail(email: email, password: password)
                presentationMode.wrappedValue.dismiss()
            } catch {
                showingAlert = true
                alertMessage = error.localizedDescription
            }
        }
    }
    
    private func validateEmail(_ email: String) {
        // Add email validation logic here
    }
    
    private func validatePassword(_ password: String) {
        // Add password validation logic here
    }
    
    private func handleAuthenticationChange(_ newValue: Bool) {
        if newValue {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func handleAuthError(_ newValue: Error?) {
        if let error = newValue {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
}

struct SignUpView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 50)
                
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    
                    Button(action: handleSignUp) {
                        Text("Sign Up")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                            .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Sign Up Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func handleSignUp() {
        guard !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty else {
            alertMessage = "Please fill in all fields"
            showingAlert = true
            return
        }
        
        guard password == confirmPassword else {
            alertMessage = "Passwords do not match"
            showingAlert = true
            return
        }
        
        Task {
            do {
                try await authManager.signUpWithEmail(email: email, password: password)
                presentationMode.wrappedValue.dismiss()
            } catch {
                showingAlert = true
                alertMessage = error.localizedDescription
            }
        }
    }
}
