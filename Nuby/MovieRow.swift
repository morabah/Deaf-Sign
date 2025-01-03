//HI 
import SwiftUI
import os.log

struct MovieRow: View {
    let movie: Movie?
    
    var body: some View {
        if let movie = movie, !movie.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            NavigationLink(destination: timelineCaptureViewHandler(movie: movie)) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(movie.title.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .accessibilityLabel(Text(LocalizedStringKey("Open timeline for \(movie.title)")))
            }
            .buttonStyle(DefaultButtonStyle())
        } else {
            VStack {
                Text("Movie information is unavailable")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                Button(action: {
                    print("Retry fetching movie information")
                }) {
                    Text("Retry")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color("PrimaryButtonColor"))
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
            }
            .padding()
        }
    }
    
    private func timelineCaptureViewHandler(movie: Movie) -> AnyView {
        AnyView(TimelineCaptureView(movie: movie))
    }
}
