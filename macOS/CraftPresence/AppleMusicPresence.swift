import Foundation
import SwiftUI
import Combine

#if os(macOS)
import AppKit

// MARK: - Apple Music Presence Manager
@MainActor
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
    
    // Cache for artwork URLs to avoid repeated API calls
    private var artworkURLCache: [String: String] = [:]  // "artist|album|track" -> URL
    private var lastArtworkFetchTrack: String = ""
    
    private init() {}
    
    // MARK: - Monitoring Control
    func startMonitoring() {
        guard monitorTimer == nil else { return }
        
        // Discord SDK 설정 확인 및 초기화
        Task {
            await ensureDiscordConfigured()
            
            // 즉시 한 번 실행
            await fetchNowPlaying()
            
            // 2초마다 Music.app 상태 확인
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.monitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                    guard let self else { return }
                    Task { await self.fetchNowPlaying() }
                }
                RunLoop.main.add(self.monitorTimer!, forMode: .common)
                
                // Discord 업데이트는 15초마다
                self.updateTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                    guard let self else { return }
                    Task { await self.updateDiscordIfNeeded() }
                }
                RunLoop.main.add(self.updateTimer!, forMode: .common)
            }
        }
    }
    
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        updateTimer?.invalidate()
        updateTimer = nil
        
        // Discord presence 제거
        Task {
            try? await DiscordSDKManager.shared.clearActivity()
        }
        
        currentTrack = ""
        currentArtist = ""
        currentAlbum = ""
        isPlaying = false
        discordStatus = "Not Connected"
        albumArtwork = nil
        albumArtworkURL = nil
    }
    
    // MARK: - Discord Configuration
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
            "set artB64 to \"\"",
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
            "set artB64 to do shell script \"base64 -i '\" & tmpPath & \"' | tr -d '\\\\n'\"",
            "set fileSize to do shell script \"wc -c < '\" & tmpPath & \"'\"",
            "set artInfo to artInfo & \",bytes:\" & fileSize",
            "do shell script \"rm -f '\" & tmpPath & \"'\"",
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
            "return t & \"||\" & ar & \"||\" & al & \"||\" & (pos as text) & \"||\" & (dur as text) & \"||\" & artB64 & \"||\" & artInfo",
            "else",
            "return \"NOT_PLAYING\"",
            "end if",
            "end tell"
        ]
        
        do {
            let output = try await runner.runWithOsascript(lines: lines)
            
            if output == "NOT_RUNNING" || output == "NOT_PLAYING" {
                // 재생 중이 아님
                if isPlaying {
                    isPlaying = false
                    albumArtwork = nil
                    Task { try? await DiscordSDKManager.shared.clearActivity() }
                }
                return
            }
            
            let parts = output.components(separatedBy: "||")
            guard parts.count >= 5 else { return }
            
            let track = parts[0]
            let artist = parts[1]
            let album = parts[2]
            let position = TimeInterval(parts[3]) ?? 0
            let duration = TimeInterval(parts[4]) ?? 0
            
            // 상태 업데이트
            let trackChanged = (track != currentTrack || artist != currentArtist)
            currentTrack = track
            currentArtist = artist
            currentAlbum = album
            currentPosition = position
            totalDuration = duration
            isPlaying = true
            
            // 앨범 아트 처리
            if parts.count >= 6 {
                let artB64 = parts[5].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
                if !artB64.isEmpty {
                    if let artData = Data(base64Encoded: artB64, options: .ignoreUnknownCharacters) {
                        if let image = NSImage(data: artData) {
                            albumArtwork = image
                        }
                    }
                }
                
                // Check cache first to avoid repeated API calls
                let cacheKey = "\(artist)|\(album)|\(track)"
                
                if let cachedURL = artworkURLCache[cacheKey] {
                    // Use cached URL
                    albumArtworkURL = cachedURL
                    print("📦 Using cached artwork URL")
                } else if trackChanged || lastArtworkFetchTrack != track {
                    // Only fetch artwork URL if track changed to reduce API calls
                    if let artworkURL = await MediaRemoteHelper.shared.fetchArtworkURL(
                        artist: artist,
                        album: album,
                        track: track
                    ) {
                        albumArtworkURL = artworkURL
                        artworkURLCache[cacheKey] = artworkURL
                        lastArtworkFetchTrack = track
                    } else if let albumURL = await MediaRemoteHelper.shared.fetchAlbumArtworkURL(
                        artist: artist,
                        album: album
                    ) {
                        albumArtworkURL = albumURL
                        artworkURLCache[cacheKey] = albumURL
                        lastArtworkFetchTrack = track
                    } else {
                        albumArtworkURL = nil
                    }
                }
                
                // If we don't have local artwork, try to fetch it for display
                if albumArtwork == nil && trackChanged {
                    if let apiImage = await MediaRemoteHelper.shared.fetchArtworkFromAPI(
                        artist: artist,
                        album: album,
                        track: track
                    ) {
                        albumArtwork = apiImage
                    } else if let albumImage = await MediaRemoteHelper.shared.fetchAlbumArtwork(
                        artist: artist,
                        album: album
                    ) {
                        albumArtwork = albumImage
                    }
                }
            } else {
                albumArtwork = nil
                albumArtworkURL = nil
            }
            
            // 트랙이 바뀌었으면 즉시 Discord 업데이트
            if trackChanged {
                await updateDiscordPresence()
            }
            
        } catch {
            print("Failed to fetch now playing: \(error)")
        }
    }
    
    // MARK: - Discord Update
    private func updateDiscordIfNeeded() async {
        guard isPlaying else { return }
        
        // Rate limiting 체크
        if let last = lastUpdateTime,
           Date().timeIntervalSince(last) < minimumUpdateInterval {
            return
        }
        
        await updateDiscordPresence()
    }
    
    private func updateDiscordPresence() async {
        guard isPlaying else { return }
        guard isDiscordConfigured else {
            print("⚠️ Discord SDK not configured yet")
            return
        }
        
        // 타임스탬프 계산 (Date 객체로 변환)
        let now = Date()
        let startDate = now.addingTimeInterval(-currentPosition)
        let endDate = now.addingTimeInterval(totalDuration - currentPosition)
        
        do {
            try await DiscordSDKManager.shared.updateActivity(
                name: "Apple Music",
                state: currentArtist.isEmpty ? "Unknown Artist" : currentArtist,
                details: currentTrack.isEmpty ? "Unknown Track" : currentTrack,
                largeImageKey: albumArtworkURL ?? "",  // 앨범 아트 URL 사용
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
