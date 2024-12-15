import SwiftUI

/// Nuby Onboarding View
///
/// This file contains the initial onboarding experience for the Nuby Movie Timeline App.
/// 
/// Purpose:
/// Provide a welcoming, informative introduction to the Nuby app, guiding new users
/// through the app's core functionality and value proposition.
///
/// Key Features:
/// - Engaging, minimalist onboarding design
/// - Clear explanation of app purpose
/// - Smooth transition to main app interface
/// - Visually appealing and intuitive user experience
///
/// Design Philosophy:
/// - Simplicity in communication
/// - Visual storytelling
/// - User-centric navigation
///
/// Technical Details:
/// - Uses SwiftUI for responsive, adaptive design
/// - State-based navigation
/// - Accessibility considerations
///
/// - Version: 1.0.0
/// - Author: Nuby Development Team
/// - Copyright: 2024 Nuby App

struct OnboardingView: View {
    /// Controls the transition from onboarding to the main content view
    @State private var isActive = false
    
    var body: some View {
        // Conditional rendering based on onboarding state
        if isActive {
            // Transition to main content view
            ContentView()
        } else {
            // Onboarding screen design
            VStack(spacing: 30) {
                // App logo and title
                Text("📦 Nuby")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Descriptive subtitle
                Text("Welcome to Your\nMovie Timeline Tracker")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                
                // Visual representation of the app
                Image(systemName: "film")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                
                // App description
                Text("Track your movie watching\nprogress with ease")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                // Get Started button
                Button(action: {
                    // Log the user's entry into the app
                    Logger.log("User completed onboarding", level: .info)
                    
                    // Track button press
                    trackGetStartedButtonPress()
                    
                    // Animate the transition to main content
                    withAnimation {
                        isActive = true
                    }
                }) {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white) // Updated for dark mode
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .onAppear {
                // Log when the onboarding view appears
                Logger.log("Onboarding view loaded", level: .debug)
            }
        }
    }
    
    /// Tracks button press for analytics or user interaction monitoring
    private func trackGetStartedButtonPress() {
        // Log detailed button press information
        Logger.log("Get Started button pressed in Onboarding", level: .debug)
        
        // Potential future analytics integration
        // AnalyticsManager.track(event: .onboardingCompleted)
    }
}
