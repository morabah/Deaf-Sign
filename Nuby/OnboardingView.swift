import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    let pages = [
        OnboardingPage(
            title: "Welcome to Nuby",
            description: "Your personal movie timeline assistant",
            imageName: "film"
        ),
        OnboardingPage(
            title: "Capture Timelines",
            description: "Use your camera to scan and save movie timestamps",
            imageName: "camera"
        ),
        OnboardingPage(
            title: "Organize Movies",
            description: "Keep track of your favorite movies and their important moments",
            imageName: "folder"
        )
    ]
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            
            Button(action: {
                if currentPage < pages.count - 1 {
                    Logger.log("Moving to next onboarding page: \(currentPage + 1)", level: .debug)
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    Logger.log("Completing onboarding", level: .info)
                    isPresented = false
                }
            }) {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            if currentPage < pages.count - 1 {
                Button(action: {
                    Logger.log("Skipping onboarding", level: .info)
                    isPresented = false
                }) {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.bottom)
            }
        }
        .onAppear {
            Logger.log("Onboarding view appeared", level: .debug)
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: page.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding()
            
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
            
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)
        }
        .padding()
    }
}
