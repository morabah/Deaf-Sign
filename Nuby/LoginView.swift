import SwiftUI
import GoogleSignIn

struct LoginView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSigningUp = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // App Logo
                Image(systemName: "hand.wave.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .padding(.top, 50)
                
                Text("Welcome to Nuby")
                    .font(.largeTitle)
                    .bold()
                
                // Sign In Form
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(.horizontal)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.password)
                        .padding(.horizontal)
                    
                    Button(action: handleLogin) {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                // Divider with "or"
                HStack {
                    VStack { Divider() }.padding(.horizontal)
                    Text("or")
                        .foregroundColor(.gray)
                    VStack { Divider() }.padding(.horizontal)
                }
                
                // Google Sign In Button
                Button(action: { authManager.signInWithGoogle() }) {
                    HStack {
                        Image("google_logo") // Add this image to your assets
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                        Text("Continue with Google")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                // Sign Up Link
                HStack {
                    Text("Don't have an account?")
                    Button(action: { isSigningUp = true }) {
                        Text("Sign Up")
                            .foregroundColor(.blue)
                            .bold()
                    }
                }
                .padding(.top)
                
                Spacer()
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    Logger.log("Login cancelled", level: .debug)
                    presentationMode.wrappedValue.dismiss()
                }
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
            }
            .onChange(of: authManager.isAuthenticated) { isAuthenticated in
                if isAuthenticated {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .onChange(of: authManager.authError) { error in
                if let error = error {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
        .onAppear {
            Logger.log("LoginView appeared", level: .debug)
        }
    }
    
    private func handleLogin() {
        Logger.log("Attempting login for email: \(email)", level: .debug)
        
        guard !email.isEmpty && !password.isEmpty else {
            alertMessage = "Please enter both email and password"
            showingAlert = true
            return
        }
        
        // Add your email/password authentication logic here
        // For now, just show an error
        alertMessage = "Email/password login not implemented yet. Please use Google Sign-In."
        showingAlert = true
    }
}

struct SignUpView: View {
    @Environment(\.presentationMode) var presentationMode
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
                    .bold()
                    .padding(.top, 50)
                
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(.horizontal)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.newPassword)
                        .padding(.horizontal)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.newPassword)
                        .padding(.horizontal)
                    
                    Button(action: handleSignUp) {
                        Text("Sign Up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
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
        
        // Add your sign up logic here
        // For now, just show an error
        alertMessage = "Sign up not implemented yet. Please use Google Sign-In."
        showingAlert = true
    }
}
