import Foundation
import SwiftUI
import Combine

#if os(macOS)

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
    
    private var monitorTimer: Timer?
    private var updateTimer: Timer?
    private var runner = ScriptRunner()
    private var lastUpdateTime: Date?
    private let minimumUpdateInterval: TimeInterval = 15.0
    private var isDiscordConfigured: Bool = false
    
    private var currentPosition: TimeInterval = 0
    private var totalDuration: TimeInterval = 0
    
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
            "return t & \"||\" & ar & \"||\" & al & \"||\" & (pos as text) & \"||\" & (dur as text)",
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
                largeImageKey: nil,
                smallImageKey: nil,
                start: startDate,
                end: endDate,
                activityType: .listening
            )
            
            lastUpdateTime = Date()
            discordStatus = "Active"
            print("✅ Discord presence updated: \(currentTrack) - \(currentArtist)")
        } catch {
            discordStatus = "Update Failed"
            print("❌ Failed to update Discord presence: \(error)")
        }
    }
}

#endif
