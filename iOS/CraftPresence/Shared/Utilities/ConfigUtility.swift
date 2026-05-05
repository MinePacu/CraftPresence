import Foundation
import UniformTypeIdentifiers

// MARK: - Settings Model
/// Persisted root settings model stored on disk for tracked apps, localization, and per-program presence options.
public struct AppSettings: Codable, Sendable, Equatable {
    // 사용자 추가 프로그램의 bundleID 목록
    public var bundleIDs: [String] = []
    public var programSettings: [String: ProgramPresenceSettings] = [:]
    public var customPresencePresets: [CustomPresencePreset] = CustomPresencePreset.defaults
    public var customPresenceDraft: CustomPresencePreset?
    public var lastCustomPresence: CustomPresencePreset?
    public var appliedCustomPresence: CustomPresencePreset?
    public var activeCustomPresencePresetID: UUID?
    public var preferredLanguage: AppLanguage = .system
    public var presencePriorityEnabled: Bool = true
    public var presenceLiveActivityEnabled: Bool = true
    
    nonisolated init() { }

    // 향후 다른 설정을 쉽게 추가하기 위한 예시 (주석 처리)
    // public var enableRichPresence: Bool = true
    // public var pollingInterval: Double = 2.0

    // Explicit nonisolated Codable to avoid main-actor isolated conformance issues in Swift 6
    private enum CodingKeys: String, CodingKey {
        case bundleIDs
        case programSettings
        case customPresencePresets
        case customPresenceDraft
        case lastCustomPresence
        case appliedCustomPresence
        case activeCustomPresencePresetID
        case preferredLanguage
        case presencePriorityEnabled
        case presenceLiveActivityEnabled
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleIDs = try container.decodeIfPresent([String].self, forKey: .bundleIDs) ?? []
        self.programSettings = try container.decodeIfPresent([String: ProgramPresenceSettings].self, forKey: .programSettings) ?? [:]
        self.customPresencePresets = try container.decodeIfPresent([CustomPresencePreset].self, forKey: .customPresencePresets) ?? CustomPresencePreset.defaults
        self.customPresenceDraft = try container.decodeIfPresent(CustomPresencePreset.self, forKey: .customPresenceDraft)
        self.lastCustomPresence = try container.decodeIfPresent(CustomPresencePreset.self, forKey: .lastCustomPresence)
        self.appliedCustomPresence = try container.decodeIfPresent(CustomPresencePreset.self, forKey: .appliedCustomPresence)
        self.activeCustomPresencePresetID = try container.decodeIfPresent(UUID.self, forKey: .activeCustomPresencePresetID)
        self.preferredLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .preferredLanguage) ?? .system
        self.presencePriorityEnabled = try container.decodeIfPresent(Bool.self, forKey: .presencePriorityEnabled) ?? true
        self.presenceLiveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .presenceLiveActivityEnabled) ?? true
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleIDs, forKey: .bundleIDs)
        try container.encode(programSettings, forKey: .programSettings)
        try container.encode(customPresencePresets, forKey: .customPresencePresets)
        try container.encodeIfPresent(customPresenceDraft, forKey: .customPresenceDraft)
        try container.encodeIfPresent(lastCustomPresence, forKey: .lastCustomPresence)
        try container.encodeIfPresent(appliedCustomPresence, forKey: .appliedCustomPresence)
        try container.encodeIfPresent(activeCustomPresencePresetID, forKey: .activeCustomPresencePresetID)
        try container.encode(preferredLanguage, forKey: .preferredLanguage)
        try container.encode(presencePriorityEnabled, forKey: .presencePriorityEnabled)
        try container.encode(presenceLiveActivityEnabled, forKey: .presenceLiveActivityEnabled)
    }
}

/// Supported language choices for the app's manual localization override.
public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case korean = "ko"
    case english = "en"
    case japanese = "ja"

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

/// User-authored Rich Presence preset that can be published manually.
public struct CustomPresencePreset: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID = UUID()
    public var title: String = ""
    public var activityType: ProgramPresenceSettings.ActivityType = .playing
    public var details: String = ""
    public var state: String = ""
    public var largeImageKey: String = ""
    public var largeImageText: String = ""
    public var smallImageKey: String = ""
    public var smallImageText: String = ""
    public var usesElapsedTime: Bool = true
    public var elapsedStartDate: Date?
    public var resetsElapsedTimeOnPublish: Bool = true
    public var usesParty: Bool = false
    public var partyCurrent: Int = 1
    public var partyMax: Int = 1

    nonisolated public init() {}

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case activityType
        case details
        case state
        case largeImageKey
        case largeImageText
        case smallImageKey
        case smallImageText
        case usesElapsedTime
        case elapsedStartDate
        case resetsElapsedTimeOnPublish
        case usesParty
        case partyCurrent
        case partyMax
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.activityType = try container.decodeIfPresent(ProgramPresenceSettings.ActivityType.self, forKey: .activityType) ?? .playing
        self.details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
        self.state = try container.decodeIfPresent(String.self, forKey: .state) ?? ""
        self.largeImageKey = try container.decodeIfPresent(String.self, forKey: .largeImageKey) ?? ""
        self.largeImageText = try container.decodeIfPresent(String.self, forKey: .largeImageText) ?? ""
        self.smallImageKey = try container.decodeIfPresent(String.self, forKey: .smallImageKey) ?? ""
        self.smallImageText = try container.decodeIfPresent(String.self, forKey: .smallImageText) ?? ""
        self.usesElapsedTime = try container.decodeIfPresent(Bool.self, forKey: .usesElapsedTime) ?? true
        self.elapsedStartDate = try container.decodeIfPresent(Date.self, forKey: .elapsedStartDate)
        self.resetsElapsedTimeOnPublish = try container.decodeIfPresent(Bool.self, forKey: .resetsElapsedTimeOnPublish) ?? true
        self.usesParty = try container.decodeIfPresent(Bool.self, forKey: .usesParty) ?? false
        self.partyCurrent = try container.decodeIfPresent(Int.self, forKey: .partyCurrent) ?? 1
        self.partyMax = try container.decodeIfPresent(Int.self, forKey: .partyMax) ?? 1
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(activityType, forKey: .activityType)
        try container.encode(details, forKey: .details)
        try container.encode(state, forKey: .state)
        try container.encode(largeImageKey, forKey: .largeImageKey)
        try container.encode(largeImageText, forKey: .largeImageText)
        try container.encode(smallImageKey, forKey: .smallImageKey)
        try container.encode(smallImageText, forKey: .smallImageText)
        try container.encode(usesElapsedTime, forKey: .usesElapsedTime)
        try container.encodeIfPresent(elapsedStartDate, forKey: .elapsedStartDate)
        try container.encode(resetsElapsedTimeOnPublish, forKey: .resetsElapsedTimeOnPublish)
        try container.encode(usesParty, forKey: .usesParty)
        try container.encode(partyCurrent, forKey: .partyCurrent)
        try container.encode(partyMax, forKey: .partyMax)
    }

    nonisolated public init(
        id: UUID = UUID(),
        title: String,
        activityType: ProgramPresenceSettings.ActivityType,
        details: String,
        state: String,
        largeImageKey: String = "",
        largeImageText: String = "",
        smallImageKey: String = "",
        smallImageText: String = "",
        usesElapsedTime: Bool = true,
        elapsedStartDate: Date? = nil,
        resetsElapsedTimeOnPublish: Bool = true,
        usesParty: Bool = false,
        partyCurrent: Int = 1,
        partyMax: Int = 1
    ) {
        self.id = id
        self.title = title
        self.activityType = activityType
        self.details = details
        self.state = state
        self.largeImageKey = largeImageKey
        self.largeImageText = largeImageText
        self.smallImageKey = smallImageKey
        self.smallImageText = smallImageText
        self.usesElapsedTime = usesElapsedTime
        self.elapsedStartDate = elapsedStartDate
        self.resetsElapsedTimeOnPublish = resetsElapsedTimeOnPublish
        self.usesParty = usesParty
        self.partyCurrent = partyCurrent
        self.partyMax = partyMax
    }

    nonisolated public static let defaults: [CustomPresencePreset] = [
        CustomPresencePreset(
            title: "Focus",
            activityType: .playing,
            details: "Deep work session",
            state: "Staying focused",
            largeImageKey: "focus",
            largeImageText: "Focus mode"
        ),
        CustomPresencePreset(
            title: "Studying",
            activityType: .watching,
            details: "Studying",
            state: "Reviewing notes",
            largeImageKey: "study",
            largeImageText: "Study session"
        ),
        CustomPresencePreset(
            title: "Coding",
            activityType: .playing,
            details: "Building CraftPresence",
            state: "Writing Swift",
            largeImageKey: "code",
            largeImageText: "Coding"
        )
    ]
}

// MARK: - Config Utility (Actor for thread-safety)
/// Actor-backed settings store that loads, mutates, and persists app configuration safely across tasks.
public actor ConfigUtility {
    public static let shared = ConfigUtility()
    public static let settingsDidChangeNotification = Notification.Name("ConfigUtilitySettingsDidChange")

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

    // MARK: Custom Presence Presets

    /// Returns all user-authored Rich Presence presets.
    public func customPresencePresets() -> [CustomPresencePreset] {
        settings.customPresencePresets
    }

    /// Returns the currently published preset when it still exists in settings.
    public func activeCustomPresencePreset() -> CustomPresencePreset? {
        guard let id = settings.activeCustomPresencePresetID else { return nil }
        return settings.customPresencePresets.first { $0.id == id }
    }

    /// Returns the Presence payload that should seed the manual customization screen.
    public func currentCustomPresenceDraft() -> CustomPresencePreset? {
        if let customPresenceDraft = settings.customPresenceDraft {
            return customPresenceDraft
        }
        if let appliedCustomPresence = settings.appliedCustomPresence {
            return appliedCustomPresence
        }
        if let activeID = settings.activeCustomPresencePresetID {
            if settings.lastCustomPresence?.id == activeID {
                return settings.lastCustomPresence
            }
            return settings.customPresencePresets.first { $0.id == activeID }
        }
        return settings.lastCustomPresence
    }

    @discardableResult
    /// Stores the in-progress custom Presence editor draft independently of the last published payload.
    public func setCustomPresenceDraft(_ preset: CustomPresencePreset?) async throws -> AppSettings {
        settings.customPresenceDraft = preset
        try persist()
        return settings
    }

    /// Returns the custom Presence that this app last applied and should keep authoritative.
    public func currentAppliedCustomPresence() -> CustomPresencePreset? {
        settings.appliedCustomPresence
    }

    /// Returns whether CraftPresence should reapply its last published custom Presence when another client changes it.
    public func isPresencePriorityEnabled() -> Bool {
        settings.presencePriorityEnabled
    }

    /// Returns whether current Presence should be mirrored to ActivityKit Live Activity surfaces.
    public func isPresenceLiveActivityEnabled() -> Bool {
        settings.presenceLiveActivityEnabled
    }

    @discardableResult
    /// Persists whether the app should keep its last published custom Presence authoritative.
    public func setPresencePriorityEnabled(_ enabled: Bool) async throws -> AppSettings {
        settings.presencePriorityEnabled = enabled
        try persist()
        return settings
    }

    @discardableResult
    /// Persists whether the app should show the current Presence as an ActivityKit Live Activity.
    public func setPresenceLiveActivityEnabled(_ enabled: Bool) async throws -> AppSettings {
        settings.presenceLiveActivityEnabled = enabled
        try persist()
        return settings
    }

    @discardableResult
    /// Adds a new custom Rich Presence preset.
    public func addCustomPresencePreset(_ preset: CustomPresencePreset) async throws -> CustomPresencePreset {
        settings.customPresencePresets.append(preset)
        try persist()
        return preset
    }

    @discardableResult
    /// Updates an existing preset or appends it when it is new.
    public func upsertCustomPresencePreset(_ preset: CustomPresencePreset) async throws -> CustomPresencePreset {
        if let index = settings.customPresencePresets.firstIndex(where: { $0.id == preset.id }) {
            settings.customPresencePresets[index] = preset
        } else {
            settings.customPresencePresets.append(preset)
        }
        try persist()
        return preset
    }

    @discardableResult
    /// Stores the latest manually published or edited custom Presence payload.
    public func setLastCustomPresence(_ preset: CustomPresencePreset?) async throws -> AppSettings {
        settings.lastCustomPresence = preset
        try persist()
        return settings
    }

    @discardableResult
    /// Stores the latest custom Presence that was actually published to Discord.
    public func setAppliedCustomPresence(_ preset: CustomPresencePreset?) async throws -> AppSettings {
        settings.appliedCustomPresence = preset
        try persist()
        return settings
    }

    @discardableResult
    /// Removes a custom preset and clears active state if that preset was published.
    public func removeCustomPresencePreset(id: UUID) async throws -> AppSettings {
        settings.customPresencePresets.removeAll { $0.id == id }
        if settings.activeCustomPresencePresetID == id {
            settings.activeCustomPresencePresetID = nil
        }
        if settings.appliedCustomPresence?.id == id {
            settings.appliedCustomPresence = nil
        }
        try persist()
        return settings
    }

    @discardableResult
    /// Stores which preset is currently published.
    public func setActiveCustomPresencePreset(id: UUID?) async throws -> AppSettings {
        settings.activeCustomPresencePresetID = id
        try persist()
        return settings
    }

    // MARK: - Persistence

    private func persist() throws {
        try ConfigUtility.persist(settings: settings, to: fileURL, with: encoder)
        Task { @MainActor in
            NotificationCenter.default.post(name: ConfigUtility.settingsDidChangeNotification, object: nil)
        }
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
