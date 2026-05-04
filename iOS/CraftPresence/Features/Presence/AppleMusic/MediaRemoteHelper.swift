import Foundation

#if os(macOS)
import AppKit
#endif

final class MediaRemoteHelper {
    static let shared = MediaRemoteHelper()

    private init() {}

    #if os(macOS)
    func fetchArtworkFromAPI(artist: String, album: String, track: String) async -> NSImage? { nil }
    func fetchAlbumArtwork(artist: String, album: String) async -> NSImage? { nil }
    #endif

    func fetchArtworkURL(artist: String, album: String, track: String) async -> String? { nil }
    func fetchAlbumArtworkURL(artist: String, album: String) async -> String? { nil }
}
