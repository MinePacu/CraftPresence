import SwiftUI
import Combine
import Foundation
#if os(macOS)
import AppKit
#endif

#if os(macOS)

// MARK: - Model
struct NowPlayingInfo: Equatable {
    var title: String
    var artist: String
    var album: String
    var position: TimeInterval
    var duration: TimeInterval
    #if os(macOS)
    var artwork: NSImage?
    #endif

    private func format(_ t: TimeInterval) -> String {
        guard t.isFinite && !t.isNaN && t >= 0 else { return "--:--" }
        let total = Int(t.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    var formattedPosition: String { format(position) }
    var formattedDuration: String { format(duration) }
}

// MARK: - ViewModel
@MainActor
final class NowPlayingViewModel: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var info: NowPlayingInfo? = nil
    @Published var statusMessage: String = ""
    @Published var errorMessage: String? = nil
    @Published var debugLog: String = ""
    @Published var showDebugLog: Bool = false

    private var runner = ScriptRunner()
    private var timer: Timer? = nil

    func fetchNowPlaying() async {
        errorMessage = nil
        statusMessage = "Querying…"
        if showDebugLog {
            debugLog = ""
        }

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
            "else if player state is paused then",
            "return \"PAUSED\"",
            "else",
            "return \"STOPPED\"",
            "end if",
            "end tell"
        ]

        do {
            let output = try await runner.runWithOsascript(lines: lines)
            if showDebugLog {
                debugLog = "Raw output length: \(output.count) chars"
            }
            
            // Parse output
            if output == "NOT_RUNNING" {
                self.info = nil
                self.statusMessage = "Music.app not running"
                return
            }
            if output == "PAUSED" {
                self.info = nil
                self.statusMessage = "Paused"
                return
            }
            if output == "STOPPED" {
                self.info = nil
                self.statusMessage = "Stopped"
                return
            }

            let parts = output.components(separatedBy: "||")
            if showDebugLog {
                debugLog += "\nParts count: \(parts.count)"
            }
            
            if parts.count >= 6 {
                let title = parts[0]
                let artist = parts[1]
                let album = parts[2]
                let pos = TimeInterval(parts[3]) ?? 0
                let dur = TimeInterval(parts[4]) ?? 0
                
                // Artwork info (part 6 if available)
                let artInfo = parts.count >= 7 ? parts[6] : "no-info"
                if showDebugLog {
                    debugLog += "\nArtwork info: \(artInfo)"
                }
                
                #if os(macOS)
                var artImage: NSImage? = nil
                let artB64 = parts[5].trimmingCharacters(in: .whitespacesAndNewlines)
                if showDebugLog {
                    debugLog += "\nBase64 length: \(artB64.count)"
                }
                
                if !artB64.isEmpty {
                    if let artData = Data(base64Encoded: artB64, options: .ignoreUnknownCharacters) {
                        if showDebugLog {
                            debugLog += "\nDecoded data size: \(artData.count) bytes"
                        }
                        if let image = NSImage(data: artData) {
                            artImage = image
                            if showDebugLog {
                                debugLog += "\nNSImage created: \(image.size)"
                            }
                        } else {
                            if showDebugLog {
                                debugLog += "\nFailed to create NSImage"
                            }
                        }
                    } else {
                        if showDebugLog {
                            debugLog += "\nFailed to decode base64"
                        }
                    }
                } else {
                    if showDebugLog {
                        debugLog += "\nNo artwork data in response"
                        debugLog += "\nTrying iTunes API..."
                    }
                    // Fallback: Try to fetch from iTunes API
                    if let apiImage = await MediaRemoteHelper.shared.fetchArtworkFromAPI(
                        artist: artist,
                        album: album,
                        track: title
                    ) {
                        artImage = apiImage
                        if showDebugLog {
                            debugLog += "\nFetched from iTunes API: \(apiImage.size)"
                        }
                    } else if let albumImage = await MediaRemoteHelper.shared.fetchAlbumArtwork(
                        artist: artist,
                        album: album
                    ) {
                        artImage = albumImage
                        if showDebugLog {
                            debugLog += "\nFetched album art from iTunes API: \(albumImage.size)"
                        }
                    } else {
                        if showDebugLog {
                            debugLog += "\niTunes API fetch failed"
                        }
                    }
                }
                
                self.info = NowPlayingInfo(title: title, artist: artist, album: album, position: pos, duration: dur, artwork: artImage)
                #else
                self.info = NowPlayingInfo(title: title, artist: artist, album: album, position: pos, duration: dur)
                #endif
                self.statusMessage = "Playing"
            } else {
                self.info = nil
                self.statusMessage = output.isEmpty ? "No data" : output
            }
        } catch {
            self.info = nil
            self.statusMessage = "Error"
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    func startAutoRefresh() {
        guard timer == nil else { return }
        // Fire immediately then every 2 seconds
        Task { await fetchNowPlaying() }
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.fetchNowPlaying() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        isRunning = true
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
}

// MARK: - View
@MainActor
struct NowPlayingTestView: View {
    @StateObject private var vm = NowPlayingViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Now Playing (Music.app)")
                .font(.headline)

            Group {
                if let info = vm.info {
                    #if os(macOS)
                    if let img = info.artwork {
                        VStack(alignment: .leading, spacing: 12) {
                            // 앨범 아트 중앙 정렬로 크게 표시
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 200, maxHeight: 200)
                                .cornerRadius(8)
                                .shadow(radius: 4)
                                .frame(maxWidth: .infinity)
                            
                            // 트랙 정보
                            VStack(alignment: .leading, spacing: 6) {
                                Text(info.title)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .lineLimit(2)
                                
                                Text(info.artist)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                
                                Text(info.album)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                
                                HStack {
                                    Text(info.formattedPosition)
                                    Spacer()
                                    Text(info.formattedDuration)
                                }
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        // 앨범 아트 없을 때
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                // 기본 플레이스홀더 아이콘
                                Image(systemName: "music.note")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, height: 80)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(info.title)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .lineLimit(2)
                                    
                                    Text(info.artist)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                    
                                    Text(info.album)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            HStack {
                                Text(info.formattedPosition)
                                Spacer()
                                Text(info.formattedDuration)
                            }
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                        }
                    }
                    #else
                    // Non-macOS won't show artwork here
                    VStack(alignment: .leading, spacing: 6) {
                        Text(info.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(info.artist)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(info.album)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("Position: \(info.formattedPosition) / \(info.formattedDuration)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    #endif
                } else {
                    Text(vm.statusMessage.isEmpty ? "—" : vm.statusMessage)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button("Refresh") { Task { await vm.fetchNowPlaying() } }
                Button(vm.isRunning ? "Auto Refresh Off" : "Auto Refresh On") {
                    vm.isRunning ? vm.stopAutoRefresh() : vm.startAutoRefresh()
                }
                
                Spacer()
                
                Toggle("Debug", isOn: $vm.showDebugLog)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            if let err = vm.errorMessage, !err.isEmpty {
                Text(err)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.red)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if vm.showDebugLog && !vm.debugLog.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug Log:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(vm.debugLog)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .task { await vm.fetchNowPlaying() }
        .navigationTitle("Test: Now Playing")
        .overlay(alignment: .topTrailing) {
            // Small indicator when auto refresh is active
            if vm.isRunning {
                Label("Auto", systemImage: "arrow.triangle.2.circlepath")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
        }
        .background(
            Group {
                // Info note for entitlements/permissions
                Color.clear
                    .overlay(alignment: .bottomLeading) {
                        Text("Note: Requires Apple Events automation permission for Music.app.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
            }
        )
    }
}

#Preview {
    NowPlayingTestView()
        .frame(width: 400, height: 500)
}

#endif

// Notes:
// - This test view uses AppleScript via osascript to query Music.app because there is no public
//   API to read the system player's now playing info directly.
// - For sandboxed apps, ensure the entitlement: com.apple.security.automation.apple-events
//   and the user must grant permission on first access.
