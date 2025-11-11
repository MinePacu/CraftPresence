import Foundation
import SwiftUI
import Combine

#if os(macOS)

// MARK: - Xcode Presence Manager
@MainActor
class XcodePresenceManager: ObservableObject {
    static let shared = XcodePresenceManager()
    
    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    @Published var currentProject: String = ""
    @Published var currentFile: String = ""
    @Published var isActive: Bool = false
    @Published var discordStatus: String = "Not Connected"
    
    private var monitorTimer: Timer?
    private var updateTimer: Timer?
    private var runner = ScriptRunner()
    private var lastUpdateTime: Date?
    private let minimumUpdateInterval: TimeInterval = 15.0
    private var isDiscordConfigured: Bool = false
    
    private init() {}
    
    // MARK: - Monitoring Control
    func startMonitoring() {
        guard monitorTimer == nil else { return }
        
        // Discord SDK 설정 확인 및 초기화
        Task {
            await ensureDiscordConfigured()
            
            // 즉시 한 번 실행
            await fetchXcodeInfo()
            
            // 3초마다 Xcode 상태 확인
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.monitorTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                    guard let self else { return }
                    Task { await self.fetchXcodeInfo() }
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
        
        currentProject = ""
        currentFile = ""
        isActive = false
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
    
    // MARK: - Fetch Xcode Info
    private func fetchXcodeInfo() async {
        // Method 1: AppleScript로 기본 정보 가져오기
        let basicInfo = await fetchBasicInfo()
        
        // Method 2: lsof로 현재 열린 파일 확인
        if basicInfo.file == "No file" {
            if let file = await fetchFileFromLsof() {
                currentProject = basicInfo.project
                currentFile = file
                isActive = true
                
                if basicInfo.project != currentProject || file != currentFile {
                    await updateDiscordPresence()
                }
                return
            }
        }
        
        // 기본 정보 사용
        let projectChanged = (basicInfo.project != currentProject || basicInfo.file != currentFile)
        currentProject = basicInfo.project
        currentFile = basicInfo.file
        isActive = basicInfo.isActive
        
        if projectChanged && isActive {
            await updateDiscordPresence()
        }
    }
    
    private func fetchBasicInfo() async -> (project: String, file: String, isActive: Bool) {
        let lines: [String] = [
            "tell application \"System Events\"",
            "set xcodeRunning to exists (process \"Xcode\")",
            "end tell",
            "if xcodeRunning is false then return \"NOT_RUNNING\"",
            "tell application \"Xcode\"",
            "try",
            "set activeDoc to active workspace document",
            "if activeDoc is missing value then return \"NO_DOCUMENT\"",
            "set projName to name of activeDoc",
            "-- Remove .xcodeproj or .xcworkspace extension",
            "if projName ends with \".xcodeproj\" then",
            "set projName to text 1 thru -11 of projName",
            "else if projName ends with \".xcworkspace\" then",
            "set projName to text 1 thru -13 of projName",
            "end if",
            "on error",
            "return \"NO_DOCUMENT\"",
            "end try",
            "end tell",
            "set currentFile to \"No file\"",
            "try",
            "tell application \"System Events\"",
            "tell process \"Xcode\"",
            "if exists front window then",
            "set windowTitle to name of front window",
            "-- Xcode window format is typically: \"ProjectName > FileName.swift\"",
            "-- or \"FileName.swift — ProjectName\" or just \"ProjectName\"",
            "-- Try different separators in order",
            "if windowTitle contains \" > \" then",
            "-- Format: \"ProjectName > FileName.swift\"",
            "set AppleScript's text item delimiters to \" > \"",
            "set titleParts to text items of windowTitle",
            "if (count of titleParts) = 2 then",
            "set currentFile to item 2 of titleParts",
            "end if",
            "set AppleScript's text item delimiters to \"\"",
            "else if windowTitle contains \" — \" then",
            "-- Format: \"FileName.swift — ProjectName\" (most common)",
            "set AppleScript's text item delimiters to \" — \"",
            "set titleParts to text items of windowTitle",
            "if (count of titleParts) = 2 then",
            "set leftPart to item 1 of titleParts",
            "set rightPart to item 2 of titleParts",
            "-- File should be the part with extension or the shorter part",
            "if leftPart contains \".\" then",
            "set currentFile to leftPart",
            "else if rightPart contains \".\" then",
            "set currentFile to rightPart",
            "else if (length of leftPart) < (length of rightPart) then",
            "set currentFile to leftPart",
            "else",
            "set currentFile to rightPart",
            "end if",
            "end if",
            "set AppleScript's text item delimiters to \"\"",
            "else if windowTitle contains \" – \" then",
            "set AppleScript's text item delimiters to \" – \"",
            "set titleParts to text items of windowTitle",
            "if (count of titleParts) = 2 then",
            "set leftPart to item 1 of titleParts",
            "set rightPart to item 2 of titleParts",
            "if leftPart contains \".\" then",
            "set currentFile to leftPart",
            "else if rightPart contains \".\" then",
            "set currentFile to rightPart",
            "else if (length of leftPart) < (length of rightPart) then",
            "set currentFile to leftPart",
            "else",
            "set currentFile to rightPart",
            "end if",
            "end if",
            "set AppleScript's text item delimiters to \"\"",
            "else if windowTitle contains \" - \" then",
            "set AppleScript's text item delimiters to \" - \"",
            "set titleParts to text items of windowTitle",
            "if (count of titleParts) = 2 then",
            "set leftPart to item 1 of titleParts",
            "set rightPart to item 2 of titleParts",
            "if leftPart contains \".\" then",
            "set currentFile to leftPart",
            "else if rightPart contains \".\" then",
            "set currentFile to rightPart",
            "else if (length of leftPart) < (length of rightPart) then",
            "set currentFile to leftPart",
            "else",
            "set currentFile to rightPart",
            "end if",
            "end if",
            "set AppleScript's text item delimiters to \"\"",
            "end if",
            "-- Final check: if currentFile is same as projName or doesn't have extension, set to No file",
            "if currentFile is not \"No file\" then",
            "if currentFile is equal to projName or currentFile does not contain \".\" then",
            "set currentFile to \"No file\"",
            "end if",
            "end if",
            "end if",
            "end tell",
            "end tell",
            "end try",
            "return projName & \"||\" & currentFile"
        ]        
        do {
            let output = try await runner.runWithOsascript(lines: lines)
            
            if output == "NOT_RUNNING" || output == "NO_DOCUMENT" {
                return ("", "No file", false)
            }
            
            if output.hasPrefix("ERROR:") {
                print("⚠️ Xcode info fetch error: \(output)")
                return ("", "No file", false)
            }
            
            let parts = output.components(separatedBy: "||")
            guard parts.count >= 2 else {
                print("⚠️ Unexpected output format: \(output)")
                return ("", "No file", false)
            }
            
            print("📝 AppleScript result - Project: \(parts[0]), File: \(parts[1])")
            return (parts[0], parts[1], true)
            
        } catch {
            print("Failed to fetch Xcode basic info: \(error)")
            return ("", "No file", false)
        }
    }
    
    private func fetchFileFromLsof() async -> String? {
        // lsof 명령으로 Xcode가 열고 있는 .swift, .m, .h 파일 찾기
        let command = "lsof -c Xcode | grep -E '\\.(swift|m|mm|h|cpp|c)$' | awk '{print $NF}' | head -1"
        
        do {
            let lines = [command]
            let output = try await runner.runWithOsascript(lines: [
                "do shell script \"\(command)\""
            ])
            
            if !output.isEmpty {
                // 경로에서 파일명만 추출
                let components = output.components(separatedBy: "/")
                if let filename = components.last, !filename.isEmpty {
                    print("📝 lsof result: \(filename)")
                    return filename.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch {
            print("lsof command failed: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Discord Update
    private func updateDiscordIfNeeded() async {
        guard isActive else { return }
        
        // Rate limiting 체크
        if let last = lastUpdateTime,
           Date().timeIntervalSince(last) < minimumUpdateInterval {
            return
        }
        
        await updateDiscordPresence()
    }
    
    private func updateDiscordPresence() async {
        guard isActive else { return }
        guard isDiscordConfigured else {
            print("⚠️ Discord SDK not configured yet")
            return
        }
        
        // 시작 시간 (현재 세션 시작)
        let startDate = Date()
        
        do {
            try await DiscordSDKManager.shared.updateActivity(
                name: "Xcode",
                state: currentFile.isEmpty || currentFile == "No file" ? "Editing..." : "Editing \(currentFile)",
                details: currentProject.isEmpty ? "Working on a project" : "Working on \(currentProject)",
                largeImageKey: nil,
                smallImageKey: nil,
                start: startDate,
                end: nil,
                activityType: .playing
            )
            
            lastUpdateTime = Date()
            discordStatus = "Active"
            print("✅ Discord presence updated: \(currentProject) - \(currentFile)")
        } catch {
            discordStatus = "Update Failed"
            print("❌ Failed to update Discord presence: \(error)")
        }
    }
}

#endif
