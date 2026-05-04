import Combine
import Foundation

#if os(iOS)
@MainActor
final class AppleMusicPresenceManager: ObservableObject {
    static let shared = AppleMusicPresenceManager()

    @Published var isEnabled: Bool = false
    @Published var currentTrack: String = ""
    @Published var currentArtist: String = ""
    @Published var currentAlbum: String = ""
    @Published var isPlaying: Bool = false
    @Published var discordStatus: String = "Unsupported on iOS"

    private init() {}
}

@MainActor
final class XcodePresenceManager: ObservableObject {
    static let shared = XcodePresenceManager()

    @Published var isEnabled: Bool = false
    @Published var currentProject: String = ""
    @Published var currentFile: String = ""
    @Published var isActive: Bool = false
    @Published var discordStatus: String = "Unsupported on iOS"

    private init() {}
}
#endif
