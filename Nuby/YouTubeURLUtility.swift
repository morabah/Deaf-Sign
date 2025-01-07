import Foundation

enum YouTubeURLUtility {
    static func isYouTubeURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("youtube.com") || host.contains("youtu.be")
    }
    
    static func getYouTubeVideoID(from url: URL) -> String? {
        let urlString = url.absoluteString
        
        // Handle youtu.be URLs
        if url.host?.lowercased() == "youtu.be" {
            return url.lastPathComponent
        }
        
        // Handle youtube.com URLs
        if let host = url.host?.lowercased(), host.contains("youtube.com") {
            if url.pathComponents.contains("embed") {
                return url.lastPathComponent
            }
            
            if let queryItems = URLComponents(string: urlString)?.queryItems {
                return queryItems.first(where: { $0.name == "v" })?.value
            }
        }
        
        return nil
    }
    
    static func getYouTubeEmbedURL(from url: URL) -> URL? {
        guard let videoID = getYouTubeVideoID(from: url) else { return nil }
        let embedURLString = "https://www.youtube.com/embed/\(videoID)?enablejsapi=1&playsinline=1&controls=1&rel=0&modestbranding=1&origin=\(Bundle.main.bundleIdentifier ?? "app")"
        return URL(string: embedURLString)
    }
    
    static func validateAndFormatURL(_ urlString: String) -> URL? {
        var formattedString = urlString
        
        // If URL doesn't start with a protocol, add https://
        if !formattedString.lowercased().hasPrefix("http") {
            formattedString = "https://" + formattedString
        }
        
        // If URL starts with http://, replace with https://
        if formattedString.lowercased().hasPrefix("http://") {
            formattedString = "https://" + formattedString.dropFirst("http://".count)
        }
        
        return URL(string: formattedString)
    }
}
