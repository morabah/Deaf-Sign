import SwiftUI

struct OnboardingView: View {
    @State private var isActive = false
    @State private var showLogin = false
    @State private var showSubscription = false

    var body: some View {
        Group {
            if isActive {
                ContentView()
            } else {
                VStack(spacing: 30) {
                    Text("📦 Nuby")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Welcome to Your\nMovie Timeline Tracker")
                        .font(.title2)
                        .multilineTextAlignment(.center)
                    
                    Image(systemName: "film")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                    
                    Text("Track your movie watching\nprogress with ease")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        isActive = true
                    }) {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        showLogin = true
                    }) {
                        Text("Log In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        showSubscription = true
                    }) {
                        Text("Free Subscription")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }
}
