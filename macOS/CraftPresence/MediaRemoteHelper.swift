import Foundation
import AppKit

#if os(macOS)

// Helper to fetch artwork from iTunes/Apple Music API when local artwork is not available
class MediaRemoteHelper {
    
    static let shared = MediaRemoteHelper()
    
    private init() {}
    
    // Fetch artwork from iTunes Search API
    func fetchArtworkFromAPI(artist: String, album: String, track: String) async -> NSImage? {
        // Build search query
        let query = "\(artist) \(album) \(track)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "https://itunes.apple.com/search?term=\(query)&media=music&entity=song&limit=1"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Parse JSON response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let firstResult = results.first,
               let artworkUrl = firstResult["artworkUrl100"] as? String {
                
                // Get higher resolution artwork by replacing 100x100 with 600x600
                let highResUrl = artworkUrl.replacingOccurrences(of: "100x100", with: "600x600")
                
                if let imageUrl = URL(string: highResUrl) {
                    // Use async URLSession instead of Data(contentsOf:)
                    let (imageData, _) = try await URLSession.shared.data(from: imageUrl)
                    if let image = NSImage(data: imageData) {
                        return image
                    }
                }
            }
        } catch {
            print("Failed to fetch artwork from API: \(error)")
        }
        
        return nil
    }
    
    // Alternative: Try to get artwork from album only (when track search fails)
    func fetchAlbumArtwork(artist: String, album: String) async -> NSImage? {
        let query = "\(artist) \(album)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "https://itunes.apple.com/search?term=\(query)&media=music&entity=album&limit=1"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let firstResult = results.first,
               let artworkUrl = firstResult["artworkUrl100"] as? String {
                
                let highResUrl = artworkUrl.replacingOccurrences(of: "100x100", with: "600x600")
                
                if let imageUrl = URL(string: highResUrl) {
                    // Use async URLSession instead of Data(contentsOf:)
                    let (imageData, _) = try await URLSession.shared.data(from: imageUrl)
                    if let image = NSImage(data: imageData) {
                        return image
                    }
                }
            }
        } catch {
            print("Failed to fetch album artwork from API: \(error)")
        }
        
        return nil
    }
}

#endif
