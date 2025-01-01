import SwiftUI

struct LoginView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Login Details")) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                
                Section {
                    Button(action: handleLogin) {
                        Text("Login")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Login")
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
        }
        .onAppear {
            Logger.log("LoginView appeared", level: .debug)
        }
    }
    
    private func handleLogin() {
        Logger.log("Attempting login for email: \(email)", level: .debug)
        
        guard !email.isEmpty && !password.isEmpty else {
            Logger.log("Login failed: Empty credentials", level: .warning)
            alertMessage = "Please enter both email and password"
            showingAlert = true
            return
        }
        
        guard email.contains("@") else {
            Logger.log("Login failed: Invalid email format", level: .warning)
            alertMessage = "Please enter a valid email address"
            showingAlert = true
            return
        }
        
        // Here you would typically make an API call to authenticate
        // For now, we'll just simulate a successful login
        Logger.log("Login successful for email: \(email)", level: .info)
        presentationMode.wrappedValue.dismiss()
    }
}
