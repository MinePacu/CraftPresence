import SwiftUI
import Foundation

#if os(macOS)

// MARK: - Model
struct NowPlayingInfo: Equatable {
    var title: String
    var artist: String
    var album: String
    var position: TimeInterval
    var duration: TimeInterval

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

    private var runner = ScriptRunner()
    private var timer: Timer? = nil

    deinit { stopAutoRefresh() }

    func fetchNowPlaying() async {
        errorMessage = nil
        statusMessage = "Querying…"

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
            "else if player state is paused then",
            "return \"PAUSED\"",
            "else",
            "return \"STOPPED\"",
            "end if",
            "end tell"
        ]

        do {
            let output = try await runner.runWithOsascript(lines: lines)
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
            if parts.count >= 5 {
                let title = parts[0]
                let artist = parts[1]
                let album = parts[2]
                let pos = TimeInterval(parts[3]) ?? 0
                let dur = TimeInterval(parts[4]) ?? 0
                self.info = NowPlayingInfo(title: title, artist: artist, album: album, position: pos, duration: dur)
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
struct NowPlayingTestView: View {
    @StateObject private var vm = NowPlayingViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Now Playing (Music.app)")
                .font(.headline)

            Group {
                if let info = vm.info {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title: \(info.title)")
                        Text("Artist: \(info.artist)")
                        Text("Album: \(info.album)")
                        Text("Position: \(info.formattedPosition) / \(info.formattedDuration)")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(vm.statusMessage.isEmpty ? "—" : vm.statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button("Refresh") { Task { await vm.fetchNowPlaying() } }
                Button(vm.isRunning ? "Auto Refresh Off" : "Auto Refresh On") {
                    vm.isRunning ? vm.stopAutoRefresh() : vm.startAutoRefresh()
                }
            }

            if let err = vm.errorMessage, !err.isEmpty {
                Text(err)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.red)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(width: 360)
}

#endif

// Notes:
// - This test view uses AppleScript via osascript to query Music.app because there is no public
//   API to read the system player's now playing info directly.
// - For sandboxed apps, ensure the entitlement: com.apple.security.automation.apple-events
//   and the user must grant permission on first access.
