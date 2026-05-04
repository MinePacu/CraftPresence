import Foundation
import AppKit

#if os(macOS)

// Helper to fetch artwork from iTunes/Apple Music API when local artwork is not available
class MediaRemoteHelper {
    
    static let shared = MediaRemoteHelper()
    
    private init() {}
    
    // URLSession with timeout configuration
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0  // 10초 타임아웃
        config.timeoutIntervalForResource = 30.0
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()
    
    // Fetch artwork from iTunes Search API
    func fetchArtworkFromAPI(artist: String, album: String, track: String) async -> NSImage? {
        // Build search query
        let query = "\(artist) \(album) \(track)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "https://itunes.apple.com/search?term=\(query)&media=music&entity=song&limit=1"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("⚠️ iTunes API returned invalid response")
                return nil
            }
            
            // Parse JSON response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let firstResult = results.first,
               let artworkUrl = firstResult["artworkUrl100"] as? String {
                
                // Get higher resolution artwork by replacing 100x100 with 600x600
                let highResUrl = artworkUrl.replacingOccurrences(of: "100x100", with: "600x600")
                
                if let imageUrl = URL(string: highResUrl) {
                    // Use async URLSession instead of Data(contentsOf:)
                    let (imageData, _) = try await urlSession.data(from: imageUrl)
                    if let image = NSImage(data: imageData) {
                        return image
                    }
                }
            }
        } catch let error as URLError {
            // Handle specific URL errors
            switch error.code {
            case .timedOut:
                print("⚠️ Artwork fetch timed out for: \(track)")
            case .notConnectedToInternet:
                print("⚠️ No internet connection")
            default:
                print("⚠️ Failed to fetch artwork from API: \(error.localizedDescription)")
            }
        } catch {
            print("⚠️ Failed to fetch artwork from API: \(error)")
        }
        
        return nil
    }
    
    // Fetch artwork URL only (for Discord Rich Presence)
    func fetchArtworkURL(artist: String, album: String, track: String) async -> String? {
        let query = "\(artist) \(album) \(track)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "https://itunes.apple.com/search?term=\(query)&media=music&entity=song&limit=1"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("⚠️ iTunes API returned invalid response for URL fetch")
                return nil
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let firstResult = results.first,
               let artworkUrl = firstResult["artworkUrl100"] as? String {
                
                // Return high resolution URL
                return artworkUrl.replacingOccurrences(of: "100x100", with: "600x600")
            }
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                print("⚠️ Artwork URL fetch timed out for: \(track)")
            default:
                print("⚠️ Failed to fetch artwork URL: \(error.localizedDescription)")
            }
        } catch {
            print("⚠️ Failed to fetch artwork URL from API: \(error)")
        }
        
        return nil
    }
    
    // Fetch album artwork URL only
    func fetchAlbumArtworkURL(artist: String, album: String) async -> String? {
        let query = "\(artist) \(album)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "https://itunes.apple.com/search?term=\(query)&media=music&entity=album&limit=1"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let firstResult = results.first,
               let artworkUrl = firstResult["artworkUrl100"] as? String {
                
                return artworkUrl.replacingOccurrences(of: "100x100", with: "600x600")
            }
        } catch let error as URLError {
            if error.code != .timedOut {
                print("⚠️ Failed to fetch album artwork URL: \(error.localizedDescription)")
            }
        } catch {
            // Silent fail for album artwork
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
            let (data, response) = try await urlSession.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let firstResult = results.first,
               let artworkUrl = firstResult["artworkUrl100"] as? String {
                
                let highResUrl = artworkUrl.replacingOccurrences(of: "100x100", with: "600x600")
                
                if let imageUrl = URL(string: highResUrl) {
                    let (imageData, _) = try await urlSession.data(from: imageUrl)
                    if let image = NSImage(data: imageData) {
                        return image
                    }
                }
            }
        } catch let error as URLError {
            if error.code == .timedOut {
                print("⚠️ Album artwork fetch timed out")
            }
        } catch {
            // Silent fail
        }
        
        return nil
    }
}

#endif
