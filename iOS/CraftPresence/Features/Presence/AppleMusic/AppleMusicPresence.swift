import Foundation
import SwiftUI
import Combine

#if os(macOS)
import AppKit

// MARK: - Simple LRU Cache for String -> String
@MainActor
/// Fixed-capacity least-recently-used cache used to cap artwork lookup memory growth.
final class LRUCache<Key: Hashable, Value> {
    private final class Node {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }

    private var dict: [Key: Node] = [:]
    private var head: Node? // most-recent
    private var tail: Node? // least-recent
    private(set) var count: Int = 0
    private let capacity: Int

    /// Creates a cache with the requested capacity, clamped to at least one entry.
    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    /// Returns the cached value for a key and promotes it to the most recently used position.
    func get(_ key: Key) -> Value? {
        guard let node = dict[key] else { return nil }
        moveToHead(node)
        return node.value
    }

    /// Stores or replaces a cached value and evicts the least recently used entry if capacity is exceeded.
    func set(_ key: Key, value: Value) {
        if let node = dict[key] {
            node.value = value
            moveToHead(node)
        } else {
            let node = Node(key: key, value: value)
            dict[key] = node
            addToHead(node)
            count += 1
            if count > capacity {
                removeTail()
            }
        }
    }

    func remove(_ key: Key) {
        guard let node = dict[key] else { return }
        removeNode(node)
        dict[key] = nil
        count -= 1
    }

    func removeAll() {
        dict.removeAll()
        head = nil
        tail = nil
        count = 0
    }

    private func addToHead(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil {
            tail = node
        }
    }

    private func moveToHead(_ node: Node) {
        guard head !== node else { return }
        removeNode(node)
        addToHead(node)
    }

    private func removeNode(_ node: Node) {
        let p = node.prev
        let n = node.next
        if let p { p.next = n } else { head = n }
        if let n { n.prev = p } else { tail = p }
        node.prev = nil
        node.next = nil
    }

    private func removeTail() {
        guard let t = tail else { return }
        removeNode(t)
        dict[t.key] = nil
        count -= 1
    }
}

// MARK: - Apple Music Presence Manager
@MainActor
/// Monitors Apple Music playback and mirrors the current track into Discord Rich Presence.
class AppleMusicPresenceManager: ObservableObject {
    static let shared = AppleMusicPresenceManager()
    
    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    @Published var currentTrack: String = ""
    @Published var currentArtist: String = ""
    @Published var currentAlbum: String = ""
    @Published var isPlaying: Bool = false
    @Published var discordStatus: String = "Not Connected"
    @Published var albumArtwork: NSImage? = nil
    @Published var albumArtworkURL: String? = nil
    
    private var monitorTimer: Timer?
    private var updateTimer: Timer?
    private var runner = ScriptRunner()
    private var lastUpdateTime: Date?
    private let minimumUpdateInterval: TimeInterval = 15.0
    private var isDiscordConfigured: Bool = false
    
    private var currentPosition: TimeInterval = 0
    private var totalDuration: TimeInterval = 0
    
    // LRU Cache for artwork URLs to avoid unbounded growth
    // Key format: "artist|album|track"
    private let artworkURLCache = LRUCache<String, String>(capacity: 200)
    private var lastArtworkFetchKey: String = ""
    
    // NSImage memory cache (auto-eviction by system pressure)
    // Cost ~= width * height * 4 bytes (RGBA 8bpc)
    private let imageCache = NSCache<NSString, NSImage>()
    private let imageCacheTotalCostLimitBytes: Int = 50 * 1024 * 1024 // ~50MB
    private let imageCacheCountLimit: Int = 300
    
    private init() {
        imageCache.totalCostLimit = imageCacheTotalCostLimitBytes
        imageCache.countLimit = imageCacheCountLimit
    }
    
    // MARK: - Monitoring Control
    /// Starts polling Music.app and scheduling Discord presence refreshes.
    func startMonitoring() {
        guard monitorTimer == nil else { return }
        
        Task {
            await ensureDiscordConfigured()
            
            // Immediate run
            await fetchNowPlaying()
            
            // Poll Music.app every 2 sec
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let monitorTimer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
                    guard let self else { return }
                    Task { await self.fetchNowPlaying() }
                }
                self.monitorTimer = monitorTimer
                RunLoop.main.add(monitorTimer, forMode: .common)
                
                // Discord update every 15 sec
                let updateTimer = Timer(timeInterval: 15.0, repeats: true) { [weak self] _ in
                    guard let self else { return }
                    Task { await self.updateDiscordIfNeeded() }
                }
                self.updateTimer = updateTimer
                RunLoop.main.add(updateTimer, forMode: .common)
            }
        }
    }
    
    /// Stops monitoring timers, clears Discord activity, and resets local playback state.
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        updateTimer?.invalidate()
        updateTimer = nil
        
        // Clear Discord presence
        Task {
            try? await DiscordSDKManager.shared.clearActivity()
        }
        resetLocalNowPlayingState()
        discordStatus = "Not Connected"
        
        // Clear caches to free memory
        artworkURLCache.removeAll()
        imageCache.removeAllObjects()
        lastArtworkFetchKey = ""
    }
    
    /// Produces a normalized cache key so artwork lookups remain stable across case and Unicode differences.
    private func normalizedCacheKey(artist: String, album: String, track: String) -> String {
        let normalizedArtist = normalizeComponent(artist)
        let normalizedAlbum = normalizeComponent(album)
        let normalizedTrack = normalizeComponent(track)
        return "\(normalizedArtist)|\(normalizedAlbum)|\(normalizedTrack)"
    }
    
    private func normalizeComponent(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.precomposedStringWithCanonicalMapping
        return normalized.lowercased()
    }
    
    private func resetLocalNowPlayingState() {
        currentTrack = ""
        currentArtist = ""
        currentAlbum = ""
        albumArtwork = nil
        albumArtworkURL = nil
        currentPosition = 0
        totalDuration = 0
        isPlaying = false
    }
    
    // MARK: - Discord Configuration
    /// Lazily configures the Discord SDK before any Apple Music activity updates are attempted.
    private func ensureDiscordConfigured() async {
        guard !isDiscordConfigured else {
            discordStatus = "Configured"
            return
        }
        
        discordStatus = "Configuring..."
        
        await MainActor.run {
            DiscordSDKManager.shared.configure(autoAuthorize: false)
        }
        
        isDiscordConfigured = true
        discordStatus = "Configured"
        print("✅ Discord SDK configured (authorization optional)")
    }
    
    // MARK: - Fetch Now Playing
    /// Queries Music.app for the current track, artwork, and playback position, then refreshes cached state.
    private func fetchNowPlaying() async {
        let lines: [String] = [
            "tell application \"System Events\"",
            "set musicRunning to exists (process \"Music\")",
            "end tell",
            "if musicRunning is false then return \"NOT_RUNNING\"",
            "tell application \"Music\"",
            "if player state is playing then",
            "set t to name of current track",
            "set ar to artist of current track",
            "set al to album of current track",
            "set pos to player position",
            "set dur to duration of current track",
            "-- Get artwork - simplified approach",
            "set artPath to \"\"",
            "set artInfo to \"none\"",
            "try",
            "set tr to current track",
            "set artCount to 0",
            "try",
            "set artCount to count of artworks of tr",
            "end try",
            "set artInfo to \"count:\" & artCount",
            "if artCount > 0 then",
            "try",
            "set tmpPath to \"/tmp/np_art_\" & (random number from 10000 to 99999) & \".jpg\"",
            "set artData to data of artwork 1 of tr",
            "set outFile to open for access POSIX file tmpPath with write permission",
            "set eof of outFile to 0",
            "write artData to outFile",
            "close access outFile",
            "set artPath to tmpPath",
            "set fileSize to do shell script \"wc -c < '\" & tmpPath & \"'\"",
            "set artInfo to artInfo & \",bytes:\" & fileSize",
            "on error errMsg",
            "set artInfo to artInfo & \",err:\" & errMsg",
            "try",
            "close access POSIX file tmpPath",
            "end try",
            "try",
            "do shell script \"rm -f '\" & tmpPath & \"'\"",
            "end try",
            "end try",
            "end if",
            "on error mainErr",
            "set artInfo to \"error:\" & mainErr",
            "end try",
            "return t & \"||\" & ar & \"||\" & al & \"||\" & (pos as text) & \"||\" & (dur as text) & \"||\" & artPath & \"||\" & artInfo",
            "else",
            "return \"NOT_PLAYING\"",
            "end if",
            "end tell"
        ]
        
        do {
            let output = try await runner.runWithOsascript(lines: lines)
            
            if output == "NOT_RUNNING" || output == "NOT_PLAYING" {
                if isPlaying {
                    Task { try? await DiscordSDKManager.shared.clearActivity() }
                }
                resetLocalNowPlayingState()
                discordStatus = (output == "NOT_RUNNING") ? "Not Connected" : "Idle"
                return
            }
            
            let parts = output.components(separatedBy: "||")
            guard parts.count >= 5 else { return }
            
            let track = parts[0]
            let artist = parts[1]
            let album = parts[2]
            let position = TimeInterval(parts[3]) ?? 0
            let duration = TimeInterval(parts[4]) ?? 0
            
            let cacheKey = normalizedCacheKey(artist: artist, album: album, track: track)
            
            let trackChanged = (track != currentTrack || artist != currentArtist || album != currentAlbum)
            currentTrack = track
            currentArtist = artist
            currentAlbum = album
            currentPosition = position
            totalDuration = duration
            isPlaying = true
            
            // 1) Try image from memory cache first
            if let cachedImage = imageCache.object(forKey: cacheKey as NSString) {
                albumArtwork = cachedImage
            }
            
            // 2) Artwork handling from AppleScript (temp file path)
            if parts.count >= 6 {
                let artPath = parts[5].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
                if !artPath.isEmpty {
                    let artURL = URL(fileURLWithPath: artPath)
                    do {
                        defer {
                            try? FileManager.default.removeItem(at: artURL)
                        }
                        let artData = try Data(contentsOf: artURL)
                        if let image = NSImage(data: artData) {
                            albumArtwork = image
                            cacheImage(image, forKey: cacheKey)
                        }
                    } catch {
                        print("Failed to read temporary artwork file: \(error)")
                        try? FileManager.default.removeItem(at: artURL)
                    }
                }
                
                // URL cache for Discord
                if let cachedURL = artworkURLCache.get(cacheKey) {
                    albumArtworkURL = cachedURL
                } else if trackChanged || lastArtworkFetchKey != cacheKey {
                    if let artworkURL = await MediaRemoteHelper.shared.fetchArtworkURL(
                        artist: artist,
                        album: album,
                        track: track
                    ) {
                        albumArtworkURL = artworkURL
                        artworkURLCache.set(cacheKey, value: artworkURL)
                        lastArtworkFetchKey = cacheKey
                    } else if let albumURL = await MediaRemoteHelper.shared.fetchAlbumArtworkURL(
                        artist: artist,
                        album: album
                    ) {
                        albumArtworkURL = albumURL
                        artworkURLCache.set(cacheKey, value: albumURL)
                        lastArtworkFetchKey = cacheKey
                    } else {
                        albumArtworkURL = nil
                    }
                }
                
                // 3) If we still don't have an image, try network APIs
                if albumArtwork == nil && trackChanged {
                    if let apiImage = await MediaRemoteHelper.shared.fetchArtworkFromAPI(
                        artist: artist,
                        album: album,
                        track: track
                    ) {
                        albumArtwork = apiImage
                        cacheImage(apiImage, forKey: cacheKey)
                    } else if let albumImage = await MediaRemoteHelper.shared.fetchAlbumArtwork(
                        artist: artist,
                        album: album
                    ) {
                        albumArtwork = albumImage
                        cacheImage(albumImage, forKey: cacheKey)
                    }
                }
            } else {
                albumArtwork = albumArtwork ?? imageCache.object(forKey: cacheKey as NSString)
                albumArtworkURL = nil
            }
            
            if trackChanged {
                await updateDiscordPresence()
            }
            
        } catch {
            print("Failed to fetch now playing: \(error)")
        }
    }
    
    // MARK: - Image Cache Helpers
    /// Stores artwork images in the memory cache using an approximate byte-size cost.
    private func cacheImage(_ image: NSImage, forKey key: String) {
        let cost = approximateByteSize(of: image)
        imageCache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    private func approximateByteSize(of image: NSImage) -> Int {
        // Rough estimate: pixels × 4 bytes (RGBA 8bpc). Use the largest rep to avoid undercounting on Retina.
        if let rep = image.representations.max(by: { ($0.pixelsWide * $0.pixelsHigh) < ($1.pixelsWide * $1.pixelsHigh) }) {
            let width = max(1, rep.pixelsWide)
            let height = max(1, rep.pixelsHigh)
            return max(1, width * height * 4)
        }
        
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let width = max(1, cgImage.width)
            let height = max(1, cgImage.height)
            return max(1, width * height * 4)
        }
        
        let size = image.size
        let width = max(1, Int(size.width))
        let height = max(1, Int(size.height))
        return max(1, width * height * 4)
    }
    
    // MARK: - Discord Update
    /// Applies a minimum refresh interval before sending another playback update to Discord.
    private func updateDiscordIfNeeded() async {
        guard isPlaying else { return }
        
        if let last = lastUpdateTime,
           Date().timeIntervalSince(last) < minimumUpdateInterval {
            return
        }
        
        await updateDiscordPresence()
    }
    
    /// Sends the current Apple Music playback session to Discord as a listening activity.
    private func updateDiscordPresence() async {
        guard isPlaying else { return }
        guard isDiscordConfigured else {
            print("⚠️ Discord SDK not configured yet")
            return
        }
        
        let now = Date()
        let startDate = now.addingTimeInterval(-currentPosition)
        let endDate = now.addingTimeInterval(totalDuration - currentPosition)
        
        do {
            try await DiscordSDKManager.shared.updateActivity(
                name: "Apple Music",
                state: currentArtist.isEmpty ? "Unknown Artist" : currentArtist,
                details: currentTrack.isEmpty ? "Unknown Track" : currentTrack,
                largeImageKey: albumArtworkURL ?? "",
                smallImageKey: "",
                start: startDate,
                end: endDate,
                activityType: .listening
            )
            
            lastUpdateTime = Date()
            discordStatus = "Active"
            print("✅ Discord presence updated: \(currentTrack) - \(currentArtist)")
            if let artURL = albumArtworkURL {
                print("   Album artwork: \(artURL)")
            }
        } catch {
            discordStatus = "Update Failed"
            print("❌ Failed to update Discord presence: \(error)")
        }
    }
}

#endif
