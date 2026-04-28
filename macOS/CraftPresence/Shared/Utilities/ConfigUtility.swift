import Foundation
import UniformTypeIdentifiers

// MARK: - Settings Model
/// Persisted root settings model stored on disk for tracked apps, localization, and per-program presence options.
public struct AppSettings: Codable, Sendable, Equatable {
    // 사용자 추가 프로그램의 bundleID 목록
    public var bundleIDs: [String] = []
    public var programSettings: [String: ProgramPresenceSettings] = [:]
    public var preferredLanguage: AppLanguage = .system
    
    nonisolated init() { }

    // 향후 다른 설정을 쉽게 추가하기 위한 예시 (주석 처리)
    // public var enableRichPresence: Bool = true
    // public var pollingInterval: Double = 2.0

    // Explicit nonisolated Codable to avoid main-actor isolated conformance issues in Swift 6
    private enum CodingKeys: String, CodingKey {
        case bundleIDs
        case programSettings
        case preferredLanguage
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleIDs = try container.decodeIfPresent([String].self, forKey: .bundleIDs) ?? []
        self.programSettings = try container.decodeIfPresent([String: ProgramPresenceSettings].self, forKey: .programSettings) ?? [:]
        self.preferredLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .preferredLanguage) ?? .system
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleIDs, forKey: .bundleIDs)
        try container.encode(programSettings, forKey: .programSettings)
        try container.encode(preferredLanguage, forKey: .preferredLanguage)
    }
}

/// Supported language choices for the app's manual localization override.
public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case korean = "ko"
    case english = "en"

    public var id: String { rawValue }
}

/// Saved Rich Presence template and asset configuration for a single tracked application.
public struct ProgramPresenceSettings: Codable, Sendable, Equatable {
    /// Discord activity kinds available when publishing a program-specific presence.
    public enum ActivityType: String, Codable, CaseIterable, Identifiable, Sendable {
        case playing = "Playing"
        case streaming = "Streaming"
        case listening = "Listening"
        case watching = "Watching"
        case competing = "Competing"

        public var id: String { rawValue }
        public var localizedLabel: String {
            switch self {
            case .playing:
                return LocalizationManager.shared.string("programs.activity.playing")
            case .streaming:
                return LocalizationManager.shared.string("programs.activity.streaming")
            case .listening:
                return LocalizationManager.shared.string("programs.activity.listening")
            case .watching:
                return LocalizationManager.shared.string("programs.activity.watching")
            case .competing:
                return LocalizationManager.shared.string("programs.activity.competing")
            }
        }
    }

    public var activityType: ActivityType = .playing
    public var detailText: String = ""
    public var stateText: String = ""
    public var useAppIconForLargeImage: Bool = true
    public var largeImageKey: String = ""
    public var largeImageText: String = ""
    public var smallImageKey: String = ""
    public var smallImageText: String = ""
    public var partyCurrent: Int = 1
    public var partyMax: Int = 1

    nonisolated public init() {}
}

// MARK: - Config Utility (Actor for thread-safety)
/// Actor-backed settings store that loads, mutates, and persists app configuration safely across tasks.
public actor ConfigUtility {
    public static let shared = ConfigUtility()

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // 현재 로드된 설정
    private var settings: AppSettings

    // 초기화 시 디스크에서 로드
    private init() {
        self.fileURL = ConfigUtility.defaultSettingsURL()
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()

        if let loaded = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode(AppSettings.self, from: loaded) {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
            try? ConfigUtility.persist(settings: self.settings, to: self.fileURL, with: self.encoder)
        }
    }

    // MARK: - Public API

    /// Returns the in-memory snapshot of the current app settings.
    public func currentSettings() -> AppSettings {
        settings
    }

    @discardableResult
    /// Replaces the full settings payload and persists it to disk.
    public func setSettings(_ newValue: AppSettings) async throws -> AppSettings {
        self.settings = newValue
        try persist()
        return settings
    }

    // MARK: BundleID helpers

    @discardableResult
    /// Adds a tracked bundle identifier if it is non-empty and not already present.
    public func addBundleID(_ id: String) async throws -> AppSettings {
        guard !id.isEmpty else { return settings }
        if !settings.bundleIDs.contains(id) {
            settings.bundleIDs.append(id)
            settings.bundleIDs.sort()
            try persist()
        }
        return settings
    }

    @discardableResult
    /// Removes a tracked bundle identifier and its saved per-program settings.
    public func removeBundleID(_ id: String) async throws -> AppSettings {
        let before = settings.bundleIDs
        settings.bundleIDs.removeAll { $0 == id }
        settings.programSettings.removeValue(forKey: id)
        if settings.bundleIDs != before {
            try persist()
        }
        return settings
    }

    /// Returns whether the given bundle identifier is already being tracked.
    public func containsBundleID(_ id: String) -> Bool {
        settings.bundleIDs.contains(id)
    }

    /// Returns saved presence settings for a bundle identifier, or default values if none exist.
    public func programSettings(for bundleID: String) -> ProgramPresenceSettings {
        settings.programSettings[bundleID] ?? ProgramPresenceSettings()
    }

    /// Returns the complete dictionary of persisted per-program presence settings.
    public func allProgramSettings() -> [String: ProgramPresenceSettings] {
        settings.programSettings
    }

    @discardableResult
    /// Persists Rich Presence settings for a specific tracked bundle identifier.
    public func setProgramSettings(_ newValue: ProgramPresenceSettings, for bundleID: String) async throws -> ProgramPresenceSettings {
        guard !bundleID.isEmpty else { return newValue }
        settings.programSettings[bundleID] = newValue
        try persist()
        return newValue
    }

    // MARK: - Persistence

    private func persist() throws {
        try ConfigUtility.persist(settings: settings, to: fileURL, with: encoder)
    }

    private static func persist(settings: AppSettings, to url: URL, with encoder: JSONEncoder) throws {
        let data = try encoder.encode(settings)
        try ensureParentDirectoryExists(for: url)
        try data.write(to: url, options: [.atomic])
    }

    private static func ensureParentDirectoryExists(for url: URL) throws {
        let dir = url.deletingLastPathComponent()
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private static func defaultSettingsURL() -> URL {
        if let overridePath = ProcessInfo.processInfo.environment["CRAFTPRESENCE_SETTINGS_PATH"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath)
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = (Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String) ?? "CraftPresence"
        return base.appendingPathComponent(bundleID, isDirectory: true)
                   .appendingPathComponent("settings.json")
    }
}
