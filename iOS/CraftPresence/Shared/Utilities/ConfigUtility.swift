import Foundation
import UniformTypeIdentifiers
#if os(iOS) && canImport(BackgroundTasks)
import BackgroundTasks
#endif

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
    public var appliedPresence: AppliedPresencePayload?
    public var activeCustomPresencePresetID: UUID?
    public var presenceScheduleRules: [PresenceScheduleRule] = []
    public var activePresenceScheduleState: ActivePresenceScheduleState?
    public var completedPresenceScheduleActivationKeys: [String: String] = [:]
    public var preferredLanguage: AppLanguage = .system
    public var presencePriorityEnabled: Bool = true
    public var presencePriorityReapplyIntervalSeconds: Int = PresencePriorityReapplyInterval.defaultSeconds
    public var presenceLiveActivityEnabled: Bool = true
    public var liveActivityContentOptions: LiveActivityContentOptions = LiveActivityContentOptions()
    public var resetElapsedTimeOnScheduledPresetRestore: Bool = false
    
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
        case appliedPresence
        case presencePresets
        case activeCustomPresencePresetID
        case activePresencePresetID
        case presenceScheduleRules
        case activePresenceScheduleState
        case completedPresenceScheduleActivationKeys
        case preferredLanguage
        case presencePriorityEnabled
        case presencePriorityReapplyIntervalSeconds
        case presenceLiveActivityEnabled
        case liveActivityContentOptions
        case resetElapsedTimeOnScheduledPresetRestore
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleIDs = try container.decodeIfPresent([String].self, forKey: .bundleIDs) ?? []
        self.programSettings = try container.decodeIfPresent([String: ProgramPresenceSettings].self, forKey: .programSettings) ?? [:]
        self.customPresencePresets = try container.decodeIfPresent([CustomPresencePreset].self, forKey: .customPresencePresets)
            ?? container.decodeIfPresent([CustomPresencePreset].self, forKey: .presencePresets)
            ?? CustomPresencePreset.defaults
        self.customPresenceDraft = try container.decodeIfPresent(CustomPresencePreset.self, forKey: .customPresenceDraft)
        self.lastCustomPresence = try container.decodeIfPresent(CustomPresencePreset.self, forKey: .lastCustomPresence)
        self.appliedCustomPresence = try container.decodeIfPresent(CustomPresencePreset.self, forKey: .appliedCustomPresence)
        self.appliedPresence = try container.decodeIfPresent(AppliedPresencePayload.self, forKey: .appliedPresence)
        self.activeCustomPresencePresetID = try container.decodeIfPresent(UUID.self, forKey: .activeCustomPresencePresetID)
            ?? container.decodeIfPresent(UUID.self, forKey: .activePresencePresetID)
        let legacyResetElapsedTimeOnScheduledPresetRestore = try container.decodeIfPresent(Bool.self, forKey: .resetElapsedTimeOnScheduledPresetRestore) ?? false
        self.resetElapsedTimeOnScheduledPresetRestore = legacyResetElapsedTimeOnScheduledPresetRestore
        self.presenceScheduleRules = (try container.decodeIfPresent([PresenceScheduleRule].self, forKey: .presenceScheduleRules) ?? [])
            .map { rule in
                var migratedRule = rule
                migratedRule.applyLegacyRestoreElapsedTimeResetDefault(legacyResetElapsedTimeOnScheduledPresetRestore)
                return migratedRule
            }
        self.activePresenceScheduleState = try container.decodeIfPresent(ActivePresenceScheduleState.self, forKey: .activePresenceScheduleState)
        self.completedPresenceScheduleActivationKeys = try container.decodeIfPresent(
            [String: String].self,
            forKey: .completedPresenceScheduleActivationKeys
        ) ?? [:]
        self.preferredLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .preferredLanguage) ?? .system
        self.presencePriorityEnabled = try container.decodeIfPresent(Bool.self, forKey: .presencePriorityEnabled) ?? true
        self.presencePriorityReapplyIntervalSeconds = PresencePriorityReapplyInterval.clamped(
            try container.decodeIfPresent(Int.self, forKey: .presencePriorityReapplyIntervalSeconds)
        )
        self.presenceLiveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .presenceLiveActivityEnabled) ?? true
        self.liveActivityContentOptions = try container.decodeIfPresent(
            LiveActivityContentOptions.self,
            forKey: .liveActivityContentOptions
        ) ?? LiveActivityContentOptions()
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleIDs, forKey: .bundleIDs)
        try container.encode(programSettings, forKey: .programSettings)
        try container.encode(customPresencePresets, forKey: .customPresencePresets)
        try container.encode(customPresencePresets, forKey: .presencePresets)
        try container.encodeIfPresent(customPresenceDraft, forKey: .customPresenceDraft)
        try container.encodeIfPresent(lastCustomPresence, forKey: .lastCustomPresence)
        try container.encodeIfPresent(appliedCustomPresence, forKey: .appliedCustomPresence)
        try container.encodeIfPresent(appliedPresence, forKey: .appliedPresence)
        try container.encodeIfPresent(activeCustomPresencePresetID, forKey: .activeCustomPresencePresetID)
        try container.encodeIfPresent(activeCustomPresencePresetID, forKey: .activePresencePresetID)
        try container.encode(presenceScheduleRules, forKey: .presenceScheduleRules)
        try container.encodeIfPresent(activePresenceScheduleState, forKey: .activePresenceScheduleState)
        try container.encode(completedPresenceScheduleActivationKeys, forKey: .completedPresenceScheduleActivationKeys)
        try container.encode(preferredLanguage, forKey: .preferredLanguage)
        try container.encode(presencePriorityEnabled, forKey: .presencePriorityEnabled)
        try container.encode(presencePriorityReapplyIntervalSeconds, forKey: .presencePriorityReapplyIntervalSeconds)
        try container.encode(presenceLiveActivityEnabled, forKey: .presenceLiveActivityEnabled)
        try container.encode(liveActivityContentOptions, forKey: .liveActivityContentOptions)
        try container.encode(resetElapsedTimeOnScheduledPresetRestore, forKey: .resetElapsedTimeOnScheduledPresetRestore)
    }
}

/// Supported interval bounds for reasserting app-owned Presence through Discord.
public enum PresencePriorityReapplyInterval {
    nonisolated public static let minimumSeconds = 10
    nonisolated public static let defaultSeconds = 30
    nonisolated public static let maximumSeconds = 300

    nonisolated public static func clamped(_ seconds: Int?) -> Int {
        min(max(seconds ?? defaultSeconds, minimumSeconds), maximumSeconds)
    }
}

/// Versioned JSON backup envelope used for importing and exporting settings.
public struct SettingsBackupFile: Codable, Sendable, Equatable {
    nonisolated public static let minimumSupportedSchemaVersion = 1
    nonisolated public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var appName: String
    public var appVersion: String?
    public var buildNumber: String?
    public var exportedAt: Date
    public var platform: String
    public var settings: AppSettings
    public var platformExtensions: [String: String]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case appName
        case appVersion
        case buildNumber
        case exportedAt
        case platform
        case settings
        case platformExtensions
    }

    nonisolated public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        appName: String = "CraftPresence",
        appVersion: String? = ConfigUtility.currentAppVersion,
        buildNumber: String? = ConfigUtility.currentBuildNumber,
        exportedAt: Date = Date(),
        platform: String = ConfigUtility.currentBackupPlatform,
        settings: AppSettings,
        platformExtensions: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.appName = appName
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.exportedAt = exportedAt
        self.platform = platform
        self.settings = settings
        self.platformExtensions = platformExtensions
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        self.appName = try container.decodeIfPresent(String.self, forKey: .appName) ?? "CraftPresence"
        self.appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion)
        self.buildNumber = try container.decodeIfPresent(String.self, forKey: .buildNumber)
        self.exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        self.platform = try container.decodeIfPresent(String.self, forKey: .platform) ?? "unknown"
        self.settings = try container.decode(AppSettings.self, forKey: .settings)
        self.platformExtensions = try container.decodeIfPresent([String: String].self, forKey: .platformExtensions) ?? [:]
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(appName, forKey: .appName)
        try container.encodeIfPresent(appVersion, forKey: .appVersion)
        try container.encodeIfPresent(buildNumber, forKey: .buildNumber)
        try container.encode(exportedAt, forKey: .exportedAt)
        try container.encode(platform, forKey: .platform)
        try container.encode(settings, forKey: .settings)
        try container.encode(platformExtensions, forKey: .platformExtensions)
    }

    nonisolated public func importSummary() -> SettingsImportSummary {
        SettingsImportSummary(
            schemaVersion: schemaVersion,
            platform: platform,
            exportedAt: exportedAt,
            presetCount: settings.customPresencePresets.count,
            trackedProgramCount: settings.bundleIDs.count,
            language: settings.preferredLanguage.rawValue,
            ignoredPlatformExtensionKeys: platformExtensions.keys.sorted()
        )
    }
}

/// Platform-neutral summary that can be shown before replacing local settings.
public struct SettingsImportSummary: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var platform: String
    public var exportedAt: Date
    public var presetCount: Int
    public var trackedProgramCount: Int
    public var language: String
    public var ignoredPlatformExtensionKeys: [String]
}

/// Validation failures that can happen before a settings backup is imported.
public enum SettingsBackupError: Error, LocalizedError, Equatable {
    case unsupportedSchemaVersion(Int)
    case duplicatePresetID(UUID)
    case scheduleReferencesMissingPreset(UUID)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "Unsupported settings backup schema version: \(version)."
        case .duplicatePresetID(let id):
            return "The settings backup contains a duplicate preset ID: \(id.uuidString)."
        case .scheduleReferencesMissingPreset(let id):
            return "The settings backup contains a schedule for a missing preset ID: \(id.uuidString)."
        }
    }
}

public enum ConfigUtilityError: Error, LocalizedError, Equatable {
    case invalidPresetReorder

    public var errorDescription: String? {
        switch self {
        case .invalidPresetReorder:
            return "Reordered presets must contain the same preset IDs."
        }
    }
}

public enum StreamingURLValidationError: Error, LocalizedError, Equatable, Sendable {
    case missing
    case invalidURL
    case unsupportedHost

    public var localizationKey: String {
        switch self {
        case .missing:
            return "presets.editor.streaming_url_error_missing"
        case .invalidURL:
            return "presets.editor.streaming_url_error_invalid"
        case .unsupportedHost:
            return "presets.editor.streaming_url_error_unsupported"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .missing:
            return "Streaming activity requires a YouTube or Twitch URL."
        case .invalidURL:
            return "Streaming URL must be a valid HTTPS link."
        case .unsupportedHost:
            return "Streaming URL must be from YouTube or Twitch."
        }
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

        nonisolated public init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "playing":
                self = .playing
            case "streaming":
                self = .streaming
            case "listening":
                self = .listening
            case "watching":
                self = .watching
            case "competing":
                self = .competing
            default:
                self = .playing
            }
        }

        nonisolated public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

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
    public var presetID: UUID?
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
    public var streamingURL: String = ""
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
    public var isDefault: Bool = false
    public var updatedAt: Date = defaultUpdatedAt

    nonisolated public init() {}

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case activityType
        case details
        case state
        case streamingURL
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
        case isDefault
        case updatedAt
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.activityType = try container.decodeIfPresent(ProgramPresenceSettings.ActivityType.self, forKey: .activityType) ?? .playing
        self.details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
        self.state = try container.decodeIfPresent(String.self, forKey: .state) ?? ""
        self.streamingURL = try container.decodeIfPresent(String.self, forKey: .streamingURL) ?? ""
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
        self.isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Self.defaultUpdatedAt
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(activityType, forKey: .activityType)
        try container.encode(details, forKey: .details)
        try container.encode(state, forKey: .state)
        try container.encode(streamingURL, forKey: .streamingURL)
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
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    nonisolated public init(
        id: UUID = UUID(),
        title: String,
        activityType: ProgramPresenceSettings.ActivityType,
        details: String,
        state: String,
        streamingURL: String = "",
        largeImageKey: String = "",
        largeImageText: String = "",
        smallImageKey: String = "",
        smallImageText: String = "",
        usesElapsedTime: Bool = true,
        elapsedStartDate: Date? = nil,
        resetsElapsedTimeOnPublish: Bool = true,
        usesParty: Bool = false,
        partyCurrent: Int = 1,
        partyMax: Int = 1,
        isDefault: Bool = false,
        updatedAt: Date = CustomPresencePreset.defaultUpdatedAt
    ) {
        self.id = id
        self.title = title
        self.activityType = activityType
        self.details = details
        self.state = state
        self.streamingURL = streamingURL
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
        self.isDefault = isDefault
        self.updatedAt = updatedAt
    }

    nonisolated public static let defaultUpdatedAt = Date(timeIntervalSince1970: 1_778_198_400)

    nonisolated public static let defaults: [CustomPresencePreset] = [
        CustomPresencePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "Coding",
            activityType: .playing,
            details: "Building CraftPresence",
            state: "Writing code",
            largeImageKey: "code",
            largeImageText: "Coding",
            isDefault: true
        ),
        CustomPresencePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Studying",
            activityType: .watching,
            details: "Studying",
            state: "Reviewing notes",
            largeImageKey: "study",
            largeImageText: "Study session",
            isDefault: true
        ),
        CustomPresencePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            title: "Focus",
            activityType: .playing,
            details: "Deep work session",
            state: "Staying focused",
            largeImageKey: "focus",
            largeImageText: "Focus mode",
            isDefault: true
        ),
        CustomPresencePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            title: "Gaming",
            activityType: .playing,
            details: "Gaming session",
            state: "In game",
            largeImageKey: "gaming",
            largeImageText: "Gaming",
            isDefault: true
        ),
        CustomPresencePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            title: "Listening",
            activityType: .listening,
            details: "Listening to music",
            state: "Now playing",
            largeImageKey: "music",
            largeImageText: "Music",
            isDefault: true
        )
    ]
}

public typealias PresencePreset = CustomPresencePreset

/// Identifies which CraftPresence feature currently owns the applied Discord Presence.
public enum AppliedPresenceSource: String, Codable, Sendable, Equatable {
    case manual
    case schedule
    case program
    case appleMusic
    case xcode
}

/// Discord Rich Presence payload last successfully applied by CraftPresence.
public struct AppliedPresencePayload: Codable, Sendable, Equatable {
    public var name: String = ""
    public var state: String?
    public var details: String?
    public var largeImageKey: String?
    public var largeImageText: String?
    public var smallImageKey: String?
    public var smallImageText: String?
    public var partyID: String?
    public var partyCurrent: Int?
    public var partyMax: Int?
    public var start: Date?
    public var end: Date?
    public var activityType: ProgramPresenceSettings.ActivityType = .playing
    public var streamingURL: String?
    public var source: AppliedPresenceSource = .manual

    private enum CodingKeys: String, CodingKey {
        case name
        case state
        case details
        case largeImageKey
        case largeImageText
        case smallImageKey
        case smallImageText
        case partyID
        case partyCurrent
        case partyMax
        case start
        case end
        case activityType
        case streamingURL
        case source
    }

    nonisolated public init(
        name: String,
        state: String? = nil,
        details: String? = nil,
        largeImageKey: String? = nil,
        largeImageText: String? = nil,
        smallImageKey: String? = nil,
        smallImageText: String? = nil,
        partyID: String? = nil,
        partyCurrent: Int? = nil,
        partyMax: Int? = nil,
        start: Date? = nil,
        end: Date? = nil,
        activityType: ProgramPresenceSettings.ActivityType = .playing,
        streamingURL: String? = nil,
        source: AppliedPresenceSource = .manual
    ) {
        self.name = Self.trimmed(name) ?? "CraftPresence"
        self.state = Self.trimmed(state)
        self.details = Self.trimmed(details)
        self.largeImageKey = Self.trimmed(largeImageKey)
        self.largeImageText = Self.trimmed(largeImageText)
        self.smallImageKey = Self.trimmed(smallImageKey)
        self.smallImageText = Self.trimmed(smallImageText)
        self.partyID = Self.trimmed(partyID)
        self.partyCurrent = partyCurrent
        self.partyMax = partyMax
        self.start = start
        self.end = end
        self.activityType = activityType
        self.streamingURL = activityType == .streaming ? Self.trimmed(streamingURL) : nil
        self.source = source
    }

    nonisolated public init(customPresencePreset preset: CustomPresencePreset) {
        self.init(customPresencePreset: preset, source: .manual)
    }

    nonisolated public init(customPresencePreset preset: CustomPresencePreset, source: AppliedPresenceSource) {
        let partyID = preset.usesParty && preset.partyCurrent > 0 && preset.partyMax >= preset.partyCurrent
            ? "preset:\(preset.id.uuidString)"
            : nil

        self.init(
            name: preset.title,
            state: preset.state,
            details: preset.details,
            largeImageKey: preset.largeImageKey,
            largeImageText: preset.largeImageText,
            smallImageKey: preset.smallImageKey,
            smallImageText: preset.smallImageText,
            partyID: partyID,
            partyCurrent: partyID == nil ? nil : preset.partyCurrent,
            partyMax: partyID == nil ? nil : preset.partyMax,
            start: preset.usesElapsedTime ? preset.elapsedStartDate : nil,
            activityType: preset.activityType,
            streamingURL: preset.streamingURL,
            source: source
        )
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = Self.trimmed(try container.decodeIfPresent(String.self, forKey: .name)) ?? "CraftPresence"
        self.state = Self.trimmed(try container.decodeIfPresent(String.self, forKey: .state))
        self.details = Self.trimmed(try container.decodeIfPresent(String.self, forKey: .details))
        self.largeImageKey = Self.trimmed(try container.decodeIfPresent(String.self, forKey: .largeImageKey))
        self.largeImageText = Self.trimmed(try container.decodeIfPresent(String.self, forKey: .largeImageText))
        self.smallImageKey = Self.trimmed(try container.decodeIfPresent(String.self, forKey: .smallImageKey))
        self.smallImageText = Self.trimmed(try container.decodeIfPresent(String.self, forKey: .smallImageText))
        self.partyID = Self.trimmed(try container.decodeIfPresent(String.self, forKey: .partyID))
        self.partyCurrent = try container.decodeIfPresent(Int.self, forKey: .partyCurrent)
        self.partyMax = try container.decodeIfPresent(Int.self, forKey: .partyMax)
        self.start = try container.decodeIfPresent(Date.self, forKey: .start)
        self.end = try container.decodeIfPresent(Date.self, forKey: .end)
        self.activityType = try container.decodeIfPresent(
            ProgramPresenceSettings.ActivityType.self,
            forKey: .activityType
        ) ?? .playing
        let decodedStreamingURL = Self.trimmed(try container.decodeIfPresent(String.self, forKey: .streamingURL))
        self.streamingURL = activityType == .streaming ? decodedStreamingURL : nil
        self.source = try container.decodeIfPresent(AppliedPresenceSource.self, forKey: .source) ?? .manual
    }

    nonisolated private static func trimmed(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == true ? nil : trimmed
    }
}

/// Time-of-day value used by schedule rules without binding it to a specific date.
public struct PresenceScheduleTime: Codable, Sendable, Equatable, Comparable {
    public var hour: Int = 9
    public var minute: Int = 0

    nonisolated public init(hour: Int = 9, minute: Int = 0) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    public static func < (lhs: PresenceScheduleTime, rhs: PresenceScheduleTime) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }

    public var minutesFromStartOfDay: Int {
        hour * 60 + minute
    }
}

/// Calendar weekday values matching `Calendar.Component.weekday` where Sunday is 1.
public enum PresenceScheduleWeekday: Int, Codable, CaseIterable, Identifiable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    public var id: Int { rawValue }
}

/// Scheduled activation mode for a Presence preset.
public enum PresenceScheduleMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case singleTime
    case timeRange

    public var id: String { rawValue }
}

/// Behavior to run after a scheduled time range no longer matches.
public enum PresenceScheduleRestorePolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case previousPresence
    case clearPresence

    public var id: String { rawValue }
}

/// User-authored schedule rule that applies one preset on matching weekdays and times.
public struct PresenceScheduleRule: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID = UUID()
    public var presetID: UUID
    public var isEnabled: Bool = true
    public var mode: PresenceScheduleMode = .timeRange
    public var weekdays: [PresenceScheduleWeekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]
    public var startTime: PresenceScheduleTime = PresenceScheduleTime(hour: 9, minute: 0)
    public var endTime: PresenceScheduleTime? = PresenceScheduleTime(hour: 18, minute: 0)
    public var excludesHolidays: Bool = false
    public var holidayRegion: String = PresenceHolidayRegion.system.rawValue
    public var restorePolicy: PresenceScheduleRestorePolicy = .previousPresence
    public var resetsElapsedTimeOnRestore: Bool = false
    public var priority: Int = 0
    public var updatedAt: Date = Date()
    private var hasExplicitResetsElapsedTimeOnRestore: Bool = true

    private enum CodingKeys: String, CodingKey {
        case id
        case presetID
        case isEnabled
        case mode
        case weekdays
        case startTime
        case endTime
        case excludesHolidays
        case holidayRegion
        case restorePolicy
        case resetsElapsedTimeOnRestore
        case priority
        case updatedAt
    }

    nonisolated public init(
        id: UUID = UUID(),
        presetID: UUID,
        isEnabled: Bool = true,
        mode: PresenceScheduleMode = .timeRange,
        weekdays: [PresenceScheduleWeekday] = [.monday, .tuesday, .wednesday, .thursday, .friday],
        startTime: PresenceScheduleTime = PresenceScheduleTime(hour: 9, minute: 0),
        endTime: PresenceScheduleTime? = PresenceScheduleTime(hour: 18, minute: 0),
        excludesHolidays: Bool = false,
        holidayRegion: String = PresenceHolidayRegion.system.rawValue,
        restorePolicy: PresenceScheduleRestorePolicy = .previousPresence,
        resetsElapsedTimeOnRestore: Bool = false,
        priority: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.presetID = presetID
        self.isEnabled = isEnabled
        self.mode = mode
        self.weekdays = weekdays.isEmpty ? [.monday] : Array(Set(weekdays)).sorted { $0.rawValue < $1.rawValue }
        self.startTime = startTime
        self.endTime = endTime
        self.excludesHolidays = excludesHolidays
        self.holidayRegion = holidayRegion
        self.restorePolicy = restorePolicy
        self.resetsElapsedTimeOnRestore = resetsElapsedTimeOnRestore
        self.priority = min(max(priority, 0), 100)
        self.updatedAt = updatedAt
        self.hasExplicitResetsElapsedTimeOnRestore = true
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        presetID = try container.decode(UUID.self, forKey: .presetID)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        mode = try container.decodeIfPresent(PresenceScheduleMode.self, forKey: .mode) ?? .timeRange
        let decodedWeekdays = try container.decodeIfPresent([PresenceScheduleWeekday].self, forKey: .weekdays) ?? [.monday, .tuesday, .wednesday, .thursday, .friday]
        weekdays = decodedWeekdays.isEmpty ? [.monday] : Array(Set(decodedWeekdays)).sorted { $0.rawValue < $1.rawValue }
        startTime = try container.decodeIfPresent(PresenceScheduleTime.self, forKey: .startTime) ?? PresenceScheduleTime(hour: 9, minute: 0)
        endTime = try container.decodeIfPresent(PresenceScheduleTime.self, forKey: .endTime)
        excludesHolidays = try container.decodeIfPresent(Bool.self, forKey: .excludesHolidays) ?? false
        holidayRegion = try container.decodeIfPresent(String.self, forKey: .holidayRegion) ?? PresenceHolidayRegion.system.rawValue
        restorePolicy = try container.decodeIfPresent(PresenceScheduleRestorePolicy.self, forKey: .restorePolicy) ?? .previousPresence
        let decodedResetOnRestore = try container.decodeIfPresent(Bool.self, forKey: .resetsElapsedTimeOnRestore)
        resetsElapsedTimeOnRestore = decodedResetOnRestore ?? false
        hasExplicitResetsElapsedTimeOnRestore = decodedResetOnRestore != nil
        priority = min(max(try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0, 0), 100)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(presetID, forKey: .presetID)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(mode, forKey: .mode)
        try container.encode(weekdays, forKey: .weekdays)
        try container.encode(startTime, forKey: .startTime)
        try container.encodeIfPresent(endTime, forKey: .endTime)
        try container.encode(excludesHolidays, forKey: .excludesHolidays)
        try container.encode(holidayRegion, forKey: .holidayRegion)
        try container.encode(restorePolicy, forKey: .restorePolicy)
        try container.encode(resetsElapsedTimeOnRestore, forKey: .resetsElapsedTimeOnRestore)
        try container.encode(priority, forKey: .priority)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    nonisolated public static func == (lhs: PresenceScheduleRule, rhs: PresenceScheduleRule) -> Bool {
        lhs.id == rhs.id &&
        lhs.presetID == rhs.presetID &&
        lhs.isEnabled == rhs.isEnabled &&
        lhs.mode == rhs.mode &&
        lhs.weekdays == rhs.weekdays &&
        sameTime(lhs.startTime, rhs.startTime) &&
        sameOptionalTime(lhs.endTime, rhs.endTime) &&
        lhs.excludesHolidays == rhs.excludesHolidays &&
        lhs.holidayRegion == rhs.holidayRegion &&
        lhs.restorePolicy == rhs.restorePolicy &&
        lhs.resetsElapsedTimeOnRestore == rhs.resetsElapsedTimeOnRestore &&
        lhs.priority == rhs.priority &&
        lhs.updatedAt == rhs.updatedAt
    }

    nonisolated private static func sameTime(_ lhs: PresenceScheduleTime, _ rhs: PresenceScheduleTime) -> Bool {
        lhs.hour == rhs.hour && lhs.minute == rhs.minute
    }

    nonisolated private static func sameOptionalTime(_ lhs: PresenceScheduleTime?, _ rhs: PresenceScheduleTime?) -> Bool {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return sameTime(lhs, rhs)
        case (nil, nil):
            return true
        default:
            return false
        }
    }

    nonisolated public mutating func applyLegacyRestoreElapsedTimeResetDefault(_ enabled: Bool) {
        guard !hasExplicitResetsElapsedTimeOnRestore else { return }
        resetsElapsedTimeOnRestore = enabled
        hasExplicitResetsElapsedTimeOnRestore = true
    }
}

/// Region basis used by offline holiday exclusion.
public enum PresenceHolidayRegion: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case kr = "KR"
    case us = "US"
    case jp = "JP"

    public var id: String { rawValue }
}

/// Tracks the currently applied schedule so ranges can restore the previous Presence when they end.
public struct ActivePresenceScheduleState: Codable, Sendable, Equatable {
    public var ruleID: UUID
    public var presetID: UUID
    public var activationKey: String
    public var mode: PresenceScheduleMode
    public var restorePolicy: PresenceScheduleRestorePolicy
    public var resetsElapsedTimeOnRestore: Bool
    public var previousPresence: AppliedPresencePayload?
    public var previousPresetID: UUID?
    public var startedAt: Date
    public var expectedEnd: Date?

    private enum CodingKeys: String, CodingKey {
        case ruleID
        case presetID
        case activationKey
        case mode
        case restorePolicy
        case resetsElapsedTimeOnRestore
        case previousPresence
        case previousPresetID
        case startedAt
        case expectedEnd
    }

    nonisolated public init(
        ruleID: UUID,
        presetID: UUID,
        activationKey: String,
        mode: PresenceScheduleMode,
        restorePolicy: PresenceScheduleRestorePolicy = .previousPresence,
        resetsElapsedTimeOnRestore: Bool = false,
        previousPresence: AppliedPresencePayload?,
        previousPresetID: UUID?,
        startedAt: Date,
        expectedEnd: Date?
    ) {
        self.ruleID = ruleID
        self.presetID = presetID
        self.activationKey = activationKey
        self.mode = mode
        self.restorePolicy = restorePolicy
        self.resetsElapsedTimeOnRestore = resetsElapsedTimeOnRestore
        self.previousPresence = previousPresence
        self.previousPresetID = previousPresetID
        self.startedAt = startedAt
        self.expectedEnd = expectedEnd
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ruleID = try container.decode(UUID.self, forKey: .ruleID)
        presetID = try container.decode(UUID.self, forKey: .presetID)
        activationKey = try container.decode(String.self, forKey: .activationKey)
        mode = try container.decode(PresenceScheduleMode.self, forKey: .mode)
        restorePolicy = try container.decodeIfPresent(PresenceScheduleRestorePolicy.self, forKey: .restorePolicy) ?? .previousPresence
        resetsElapsedTimeOnRestore = try container.decodeIfPresent(Bool.self, forKey: .resetsElapsedTimeOnRestore) ?? false
        previousPresence = try container.decodeIfPresent(AppliedPresencePayload.self, forKey: .previousPresence)
        previousPresetID = try container.decodeIfPresent(UUID.self, forKey: .previousPresetID)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        expectedEnd = try container.decodeIfPresent(Date.self, forKey: .expectedEnd)
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ruleID, forKey: .ruleID)
        try container.encode(presetID, forKey: .presetID)
        try container.encode(activationKey, forKey: .activationKey)
        try container.encode(mode, forKey: .mode)
        try container.encode(restorePolicy, forKey: .restorePolicy)
        try container.encode(resetsElapsedTimeOnRestore, forKey: .resetsElapsedTimeOnRestore)
        try container.encodeIfPresent(previousPresence, forKey: .previousPresence)
        try container.encodeIfPresent(previousPresetID, forKey: .previousPresetID)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(expectedEnd, forKey: .expectedEnd)
    }
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

    /// Platform value written into exported settings backup metadata.
    public nonisolated static var currentBackupPlatform: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #else
        return "unknown"
        #endif
    }

    /// App version written into exported settings backup metadata.
    public nonisolated static var currentAppVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// Build number written into exported settings backup metadata.
    public nonisolated static var currentBuildNumber: String? {
        Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
    }

    /// Default user-facing filename for an exported settings backup.
    public nonisolated static func defaultSettingsBackupFilename(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "CraftPresence-Settings-\(formatter.string(from: now)).craftpresence.json"
    }

    /// Encodes the supplied settings into the versioned JSON backup format.
    public nonisolated static func encodeSettingsBackup(
        settings: AppSettings,
        exportedAt: Date = Date(),
        platform: String = ConfigUtility.currentBackupPlatform,
        appVersion: String? = ConfigUtility.currentAppVersion,
        buildNumber: String? = ConfigUtility.currentBuildNumber,
        platformExtensions: [String: String] = [:]
    ) throws -> Data {
        let backup = SettingsBackupFile(
            appVersion: appVersion,
            buildNumber: buildNumber,
            exportedAt: exportedAt,
            platform: platform,
            settings: sanitizedSettingsForBackup(settings),
            platformExtensions: platformExtensions
        )
        return try backupJSONEncoder().encode(backup)
    }

    /// Decodes and validates a versioned JSON settings backup without applying it.
    public nonisolated static func decodeSettingsBackup(from data: Data) throws -> SettingsBackupFile {
        let decoder = backupJSONDecoder()

        do {
            let backup = try decoder.decode(SettingsBackupFile.self, from: data)
            try validateSettingsBackup(backup)
            return backup
        } catch let error as SettingsBackupError {
            throw error
        } catch {
            if let legacySettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
                let backup = SettingsBackupFile(
                    appName: "CraftPresence",
                    appVersion: nil,
                    buildNumber: nil,
                    exportedAt: Date(timeIntervalSince1970: 0),
                    platform: "legacy",
                    settings: sanitizedSettingsForBackup(legacySettings),
                    platformExtensions: [:]
                )
                try validateSettingsBackup(backup)
                return backup
            }

            throw error
        }
    }

    /// Validates settings backup structure before import.
    public nonisolated static func validateSettingsBackup(_ backup: SettingsBackupFile) throws {
        guard backup.schemaVersion >= SettingsBackupFile.minimumSupportedSchemaVersion,
              backup.schemaVersion <= SettingsBackupFile.currentSchemaVersion else {
            throw SettingsBackupError.unsupportedSchemaVersion(backup.schemaVersion)
        }

        let presetIDs = backup.settings.customPresencePresets.map(\.id)
        let uniquePresetIDs = Set(presetIDs)
        if presetIDs.count != uniquePresetIDs.count,
           let duplicateID = presetIDs.first(where: { id in presetIDs.filter { $0 == id }.count > 1 }) {
            throw SettingsBackupError.duplicatePresetID(duplicateID)
        }

        for rule in backup.settings.presenceScheduleRules where !uniquePresetIDs.contains(rule.presetID) {
            throw SettingsBackupError.scheduleReferencesMissingPreset(rule.presetID)
        }
    }

    public nonisolated static func validateCustomPresencePresetReorder(
        existing: [CustomPresencePreset],
        reordered: [CustomPresencePreset]
    ) throws {
        let existingIDs = existing.map(\.id.uuidString).sorted()
        let reorderedIDs = reordered.map(\.id.uuidString).sorted()
        guard existingIDs == reorderedIDs else {
            throw ConfigUtilityError.invalidPresetReorder
        }
    }

    /// Returns the data users can save as a `.json` settings backup file.
    public func exportSettingsBackup(
        exportedAt: Date = Date(),
        platform: String = ConfigUtility.currentBackupPlatform,
        appVersion: String? = ConfigUtility.currentAppVersion,
        buildNumber: String? = ConfigUtility.currentBuildNumber
    ) throws -> Data {
        try ConfigUtility.encodeSettingsBackup(
            settings: settings,
            exportedAt: exportedAt,
            platform: platform,
            appVersion: appVersion,
            buildNumber: buildNumber
        )
    }

    @discardableResult
    /// Imports a decoded settings backup after clearing runtime-only state.
    public func importSettingsBackup(_ backup: SettingsBackupFile) async throws -> AppSettings {
        try ConfigUtility.validateSettingsBackup(backup)
        settings = ConfigUtility.settingsForImport(from: backup)
        try persist()
        return settings
    }

    @discardableResult
    /// Decodes, validates, and imports settings backup data.
    public func importSettingsBackup(from data: Data) async throws -> AppSettings {
        let backup = try ConfigUtility.decodeSettingsBackup(from: data)
        return try await importSettingsBackup(backup)
    }

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

    /// Returns the Presence payload that priority enforcement should keep authoritative.
    public func currentAppliedPresence() -> AppliedPresencePayload? {
        settings.appliedPresence ?? settings.appliedCustomPresence.map {
            AppliedPresencePayload(customPresencePreset: $0)
        }
    }

    /// Returns whether CraftPresence should reapply its last published custom Presence when another client changes it.
    public func isPresencePriorityEnabled() -> Bool {
        settings.presencePriorityEnabled
    }

    /// Returns the interval between periodic app-owned Presence reassertions.
    public func presencePriorityReapplyIntervalSeconds() -> Int {
        settings.presencePriorityReapplyIntervalSeconds
    }

    /// Returns whether current Presence should be mirrored to ActivityKit Live Activity surfaces.
    public func isPresenceLiveActivityEnabled() -> Bool {
        settings.presenceLiveActivityEnabled
    }

    /// Returns which fields should appear on ActivityKit Live Activity surfaces.
    public func liveActivityContentOptions() -> LiveActivityContentOptions {
        settings.liveActivityContentOptions
    }

    @discardableResult
    /// Persists whether the app should keep its last published custom Presence authoritative.
    public func setPresencePriorityEnabled(_ enabled: Bool) async throws -> AppSettings {
        settings.presencePriorityEnabled = enabled
        try persist()
        return settings
    }

    @discardableResult
    /// Persists the interval between periodic app-owned Presence reassertions.
    public func setPresencePriorityReapplyIntervalSeconds(_ seconds: Int) async throws -> AppSettings {
        settings.presencePriorityReapplyIntervalSeconds = PresencePriorityReapplyInterval.clamped(seconds)
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
    /// Persists which fields should appear on ActivityKit Live Activity surfaces.
    public func setLiveActivityContentOptions(_ options: LiveActivityContentOptions) async throws -> AppSettings {
        settings.liveActivityContentOptions = options
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
    /// Persists a reordered preset list without changing preset identity.
    public func setCustomPresencePresets(_ presets: [CustomPresencePreset]) async throws -> AppSettings {
        try ConfigUtility.validateCustomPresencePresetReorder(
            existing: settings.customPresencePresets,
            reordered: presets
        )
        settings.customPresencePresets = presets
        try persist()
        return settings
    }

    @discardableResult
    /// Creates a copy of a preset with a new identifier so users can edit it independently.
    public func duplicateCustomPresencePreset(id: UUID, title: String? = nil) async throws -> CustomPresencePreset? {
        guard let source = settings.customPresencePresets.first(where: { $0.id == id }) else { return nil }
        var copy = source
        copy.id = UUID()
        copy.title = title ?? source.title
        copy.isDefault = false
        copy.updatedAt = Date()
        settings.customPresencePresets.append(copy)
        try persist()
        return copy
    }

    @discardableResult
    /// Restores only missing built-in Presence presets while leaving user edits and deletions intact.
    public func restoreDefaultPresencePresets() async throws -> AppSettings {
        let existingIDs = Set(settings.customPresencePresets.map(\.id))
        let missingDefaults = CustomPresencePreset.defaults.filter { !existingIDs.contains($0.id) }
        guard !missingDefaults.isEmpty else { return settings }
        settings.customPresencePresets.append(contentsOf: missingDefaults)
        try persist()
        return settings
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
        settings.appliedPresence = preset.map {
            AppliedPresencePayload(customPresencePreset: $0)
        }
        try persist()
        return settings
    }

    @discardableResult
    /// Stores the latest app-owned Presence payload that was actually published to Discord.
    public func setAppliedPresence(_ payload: AppliedPresencePayload?) async throws -> AppSettings {
        settings.appliedPresence = payload
        settings.appliedCustomPresence = nil
        try persist()
        return settings
    }

    @discardableResult
    /// Clears the stored app-owned Presence only when it belongs to the supplied source.
    public func clearAppliedPresence(ifOwnedBy source: AppliedPresenceSource) async throws -> AppSettings {
        let currentPayload = settings.appliedPresence ?? settings.appliedCustomPresence.map {
            AppliedPresencePayload(customPresencePreset: $0)
        }
        guard currentPayload?.source == source else { return settings }
        settings.appliedPresence = nil
        settings.appliedCustomPresence = nil
        try persist()
        return settings
    }

    @discardableResult
    /// Removes a custom preset and clears active state if that preset was published.
    public func removeCustomPresencePreset(id: UUID) async throws -> AppSettings {
        settings.customPresencePresets.removeAll { $0.id == id }
        settings.presenceScheduleRules.removeAll { $0.presetID == id }
        if settings.activeCustomPresencePresetID == id {
            settings.activeCustomPresencePresetID = nil
        }
        if settings.appliedCustomPresence?.id == id {
            settings.appliedCustomPresence = nil
            settings.appliedPresence = nil
        }
        if settings.activePresenceScheduleState?.presetID == id {
            settings.activePresenceScheduleState = nil
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

    // MARK: Presence Schedules

    /// Returns all saved schedule rules.
    public func presenceScheduleRules() -> [PresenceScheduleRule] {
        settings.presenceScheduleRules
    }

    /// Returns schedule rules attached to a specific preset.
    public func presenceScheduleRules(for presetID: UUID) -> [PresenceScheduleRule] {
        settings.presenceScheduleRules
            .filter { $0.presetID == presetID }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    @discardableResult
    /// Updates an existing schedule rule or appends it when it is new.
    public func upsertPresenceScheduleRule(_ rule: PresenceScheduleRule) async throws -> PresenceScheduleRule {
        var next = rule
        next.updatedAt = Date()
        if let index = settings.presenceScheduleRules.firstIndex(where: { $0.id == rule.id }) {
            settings.presenceScheduleRules[index] = next
        } else {
            settings.presenceScheduleRules.append(next)
        }
        settings.completedPresenceScheduleActivationKeys.removeValue(forKey: rule.id.uuidString)
        try persist()
        await PresenceScheduleBackgroundScheduler.shared.scheduleNextWake()
        return next
    }

    @discardableResult
    /// Deletes a schedule rule and clears active schedule state if that rule is running.
    public func removePresenceScheduleRule(id: UUID) async throws -> AppSettings {
        settings.presenceScheduleRules.removeAll { $0.id == id }
        settings.completedPresenceScheduleActivationKeys.removeValue(forKey: id.uuidString)
        if settings.activePresenceScheduleState?.ruleID == id {
            settings.activePresenceScheduleState = nil
        }
        try persist()
        await PresenceScheduleBackgroundScheduler.shared.scheduleNextWake()
        return settings
    }

    /// Returns the schedule state currently owned by the automatic scheduler.
    public func activePresenceScheduleState() -> ActivePresenceScheduleState? {
        settings.activePresenceScheduleState
    }

    @discardableResult
    /// Stores or clears the schedule state currently owned by the automatic scheduler.
    public func setActivePresenceScheduleState(_ state: ActivePresenceScheduleState?) async throws -> AppSettings {
        settings.activePresenceScheduleState = state
        try persist()
        return settings
    }

    @discardableResult
    /// Records a completed schedule activation so catch-up windows do not apply it more than once.
    public func recordCompletedPresenceScheduleActivation(ruleID: UUID, activationKey: String) async throws -> AppSettings {
        settings.completedPresenceScheduleActivationKeys[ruleID.uuidString] = activationKey
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

    private nonisolated static func settingsForImport(from backup: SettingsBackupFile) -> AppSettings {
        switch backup.schemaVersion {
        case 1:
            return sanitizedSettingsForBackup(backup.settings)
        default:
            return sanitizedSettingsForBackup(backup.settings)
        }
    }

    private nonisolated static func sanitizedSettingsForBackup(_ settings: AppSettings) -> AppSettings {
        var sanitized = settings
        sanitized.appliedCustomPresence = nil
        sanitized.appliedPresence = nil
        sanitized.activeCustomPresencePresetID = nil
        sanitized.activePresenceScheduleState = nil
        sanitized.completedPresenceScheduleActivationKeys = [:]
        return sanitized
    }

    private nonisolated static func backupJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private nonisolated static func backupJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// Pure schedule evaluation helpers separated from Discord publishing side effects.
public enum PresenceScheduleEvaluator {
    public static let singleTimeGraceInterval: TimeInterval = 10 * 60

    public struct Match: Sendable, Equatable {
        public var rule: PresenceScheduleRule
        public var preset: CustomPresencePreset
        public var activationKey: String
        public var expectedEnd: Date?
    }

    public static func activeMatch(
        in settings: AppSettings,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> Match? {
        let presetsByID = Dictionary(uniqueKeysWithValues: settings.customPresencePresets.map { ($0.id, $0) })
        return settings.presenceScheduleRules
            .compactMap { rule -> Match? in
                guard rule.isEnabled,
                      let preset = presetsByID[rule.presetID],
                      !isExcludedHoliday(rule: rule, now: now, calendar: calendar),
                      let interval = activeInterval(for: rule, now: now, calendar: calendar) else {
                    return nil
                }

                let activationKey = activationKey(for: rule, occurrenceStart: interval.start, calendar: calendar)
                if rule.mode == .singleTime,
                   settings.completedPresenceScheduleActivationKeys[rule.id.uuidString] == activationKey {
                    return nil
                }

                return Match(
                    rule: rule,
                    preset: preset,
                    activationKey: activationKey,
                    expectedEnd: interval.end
                )
            }
            .sorted { lhs, rhs in
                if lhs.rule.priority != rhs.rule.priority { return lhs.rule.priority > rhs.rule.priority }
                if lhs.rule.updatedAt != rhs.rule.updatedAt { return lhs.rule.updatedAt > rhs.rule.updatedAt }
                return lhs.rule.id.uuidString < rhs.rule.id.uuidString
            }
            .first
    }

    private static func activeInterval(
        for rule: PresenceScheduleRule,
        now: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date?)? {
        switch rule.mode {
        case .singleTime:
            return singleTimeInterval(for: rule, now: now, calendar: calendar)
        case .timeRange:
            return timeRangeInterval(for: rule, now: now, calendar: calendar)
        }
    }

    private static func singleTimeInterval(
        for rule: PresenceScheduleRule,
        now: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date?)? {
        let weekday = calendar.component(.weekday, from: now)
        guard rule.weekdays.contains(where: { $0.rawValue == weekday }) else { return nil }
        let start = date(onSameDayAs: now, time: rule.startTime, calendar: calendar)
        let end = start.addingTimeInterval(singleTimeGraceInterval)
        guard now >= start, now <= end else { return nil }
        return (start: start, end: end)
    }

    private static func timeRangeInterval(
        for rule: PresenceScheduleRule,
        now: Date,
        calendar: Calendar
    ) -> (start: Date, end: Date?)? {
        guard let endTime = rule.endTime else { return nil }
        let currentMinutes = minutesFromStartOfDay(for: now, calendar: calendar)
        let startMinutes = rule.startTime.minutesFromStartOfDay
        let endMinutes = endTime.minutesFromStartOfDay
        let weekday = calendar.component(.weekday, from: now)

        if startMinutes < endMinutes {
            guard rule.weekdays.contains(where: { $0.rawValue == weekday }),
                  currentMinutes >= startMinutes,
                  currentMinutes < endMinutes else {
                return nil
            }
            return (
                start: date(onSameDayAs: now, time: rule.startTime, calendar: calendar),
                end: date(onSameDayAs: now, time: endTime, calendar: calendar)
            )
        }

        if currentMinutes >= startMinutes,
           rule.weekdays.contains(where: { $0.rawValue == weekday }) {
            let start = date(onSameDayAs: now, time: rule.startTime, calendar: calendar)
            return (start: start, end: calendar.date(byAdding: .day, value: 1, to: date(onSameDayAs: now, time: endTime, calendar: calendar)))
        }

        let previousDay = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let previousWeekday = calendar.component(.weekday, from: previousDay)
        guard currentMinutes < endMinutes,
              rule.weekdays.contains(where: { $0.rawValue == previousWeekday }) else {
            return nil
        }
        return (
            start: date(onSameDayAs: previousDay, time: rule.startTime, calendar: calendar),
            end: date(onSameDayAs: now, time: endTime, calendar: calendar)
        )
    }

    private static func isExcludedHoliday(
        rule: PresenceScheduleRule,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard rule.excludesHolidays else { return false }
        return PresenceHolidayCalendar.isHoliday(
            now,
            region: PresenceHolidayRegion(rawValue: rule.holidayRegion) ?? .system,
            calendar: calendar
        )
    }

    public static func activationKey(
        for rule: PresenceScheduleRule,
        occurrenceStart: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: occurrenceStart)
        let year = String(components.year ?? 0)
        let month = String(components.month ?? 0)
        let day = String(components.day ?? 0)
        let hour = String(components.hour ?? 0)
        let minute = String(components.minute ?? 0)
        return [rule.id.uuidString, year, month, day, hour, minute].joined(separator: "-")
    }

    private static func date(
        onSameDayAs date: Date,
        time: PresenceScheduleTime,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            bySettingHour: time.hour,
            minute: time.minute,
            second: 0,
            of: date
        ) ?? date
    }

    private static func minutesFromStartOfDay(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

/// Offline holiday detector for the schedule exclusion option.
public enum PresenceHolidayCalendar {
    public static func isHoliday(
        _ date: Date,
        region: PresenceHolidayRegion,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        let resolvedRegion = resolve(region)
        let components = calendar.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else { return false }

        switch resolvedRegion {
        case .kr:
            return [(1, 1), (3, 1), (5, 5), (6, 6), (8, 15), (10, 3), (10, 9), (12, 25)].contains { $0 == (month, day) }
        case .us:
            return [(1, 1), (6, 19), (7, 4), (11, 11), (12, 25)].contains { $0 == (month, day) }
        case .jp:
            return [(1, 1), (2, 11), (2, 23), (4, 29), (5, 3), (5, 4), (5, 5), (8, 11), (11, 3), (11, 23)].contains { $0 == (month, day) }
        case .system:
            return false
        }
    }

    private static func resolve(_ region: PresenceHolidayRegion) -> PresenceHolidayRegion {
        guard region == .system else { return region }
        let identifier: String?
        if #available(iOS 16.0, macOS 13.0, *) {
            identifier = Locale.autoupdatingCurrent.region?.identifier
        } else {
            identifier = Locale.autoupdatingCurrent.regionCode
        }

        switch identifier?.uppercased() {
        case PresenceHolidayRegion.kr.rawValue:
            return .kr
        case PresenceHolidayRegion.us.rawValue:
            return .us
        case PresenceHolidayRegion.jp.rawValue:
            return .jp
        default:
            return .system
        }
    }
}

/// Computes the next useful scheduler wakeup from persisted schedule rules.
public enum PresenceScheduleBackgroundPlan {
    public static func nextWakeDate(
        in settings: AppSettings,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date? {
        let presetsByID = Set(settings.customPresencePresets.map(\.id))
        let candidates = settings.presenceScheduleRules
            .filter { $0.isEnabled && presetsByID.contains($0.presetID) }
            .flatMap { wakeCandidates(for: $0, settings: settings, now: now, calendar: calendar) }
            .filter { $0 >= now }
        return candidates.min()
    }

    private static func wakeCandidates(
        for rule: PresenceScheduleRule,
        settings: AppSettings,
        now: Date,
        calendar: Calendar
    ) -> [Date] {
        var dates: [Date] = []
        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            guard rule.weekdays.contains(where: { $0.rawValue == weekday }),
                  !isExcludedHoliday(rule: rule, day: day, calendar: calendar) else {
                continue
            }

            let start = date(onSameDayAs: day, time: rule.startTime, calendar: calendar)
            switch rule.mode {
            case .singleTime:
                let activationKey = PresenceScheduleEvaluator.activationKey(
                    for: rule,
                    occurrenceStart: start,
                    calendar: calendar
                )
                if settings.completedPresenceScheduleActivationKeys[rule.id.uuidString] != activationKey {
                    dates.append(max(now, start))
                }
            case .timeRange:
                dates.append(start)
                if let endTime = rule.endTime {
                    let end = endDate(for: rule, day: day, endTime: endTime, calendar: calendar)
                    dates.append(end)
                }
            }
        }
        return dates
    }

    private static func endDate(
        for rule: PresenceScheduleRule,
        day: Date,
        endTime: PresenceScheduleTime,
        calendar: Calendar
    ) -> Date {
        let end = date(onSameDayAs: day, time: endTime, calendar: calendar)
        guard rule.startTime.minutesFromStartOfDay >= endTime.minutesFromStartOfDay else { return end }
        return calendar.date(byAdding: .day, value: 1, to: end) ?? end
    }

    private static func isExcludedHoliday(
        rule: PresenceScheduleRule,
        day: Date,
        calendar: Calendar
    ) -> Bool {
        guard rule.excludesHolidays else { return false }
        return PresenceHolidayCalendar.isHoliday(
            day,
            region: PresenceHolidayRegion(rawValue: rule.holidayRegion) ?? .system,
            calendar: calendar
        )
    }

    private static func date(
        onSameDayAs date: Date,
        time: PresenceScheduleTime,
        calendar: Calendar
    ) -> Date {
        calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: date) ?? date
    }
}

/// Periodically evaluates Presence schedules and publishes or restores Presence when rules change state.
@MainActor
public final class PresenceScheduleManager {
    public static let shared = PresenceScheduleManager()

    private var scheduleTask: Task<Void, Never>?
    private let intervalNanoseconds: UInt64 = 30_000_000_000

    private init() {}

    public func start() {
        guard scheduleTask == nil, !AutomationLaunchOptions.isUITesting else { return }
        Task {
            await PresenceScheduleBackgroundScheduler.shared.scheduleNextWake()
        }
        scheduleTask = Task { [weak self] in
            guard let self else { return }
            await evaluate()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                await evaluate()
            }
        }
    }

    public func stop() {
        scheduleTask?.cancel()
        scheduleTask = nil
    }

    public func evaluate(now: Date = Date()) async {
        let settings = await ConfigUtility.shared.currentSettings()
        let match = PresenceScheduleEvaluator.activeMatch(in: settings, now: now)

        if let match {
            guard settings.activePresenceScheduleState?.ruleID != match.rule.id ||
                    settings.activePresenceScheduleState?.activationKey != match.activationKey else {
                return
            }
            await apply(match, previousSettings: settings, now: now)
            return
        }

        if let active = settings.activePresenceScheduleState {
            await end(active, now: now)
        }
    }

    private func apply(
        _ match: PresenceScheduleEvaluator.Match,
        previousSettings settings: AppSettings,
        now: Date
    ) async {
        var preset = match.preset
        if preset.usesElapsedTime {
            preset.elapsedStartDate = preset.resetsElapsedTimeOnPublish ? now : (preset.elapsedStartDate ?? now)
        } else {
            preset.elapsedStartDate = nil
        }

        let payload = AppliedPresencePayload(customPresencePreset: preset, source: .schedule)
        let previousPresence = settings.activePresenceScheduleState?.previousPresence ?? settings.currentAppliedPresencePayload
        let previousPresetID = settings.activePresenceScheduleState?.previousPresetID ?? settings.activeCustomPresencePresetID

        do {
            try await DiscordSDKManager.shared.publishAppliedPresence(payload)
            _ = try await ConfigUtility.shared.setLastCustomPresence(preset)
            _ = try await ConfigUtility.shared.setActiveCustomPresencePreset(id: preset.id)
            if match.rule.mode == .singleTime {
                _ = try await ConfigUtility.shared.recordCompletedPresenceScheduleActivation(
                    ruleID: match.rule.id,
                    activationKey: match.activationKey
                )
            }
            _ = try await ConfigUtility.shared.setActivePresenceScheduleState(
                ActivePresenceScheduleState(
                    ruleID: match.rule.id,
                    presetID: preset.id,
                    activationKey: match.activationKey,
                    mode: match.rule.mode,
                    restorePolicy: match.rule.restorePolicy,
                    resetsElapsedTimeOnRestore: match.rule.resetsElapsedTimeOnRestore,
                    previousPresence: previousPresence,
                    previousPresetID: previousPresetID,
                    startedAt: now,
                    expectedEnd: match.expectedEnd
                )
            )
            await PresenceLiveActivityController.shared.publish(
                preset,
                connectionStatus: LocalizationManager.shared.string(DiscordSDKManager.shared.dashboardStatus.localizationKey)
            )
            await PresenceScheduleBackgroundScheduler.shared.scheduleNextWake()
        } catch {
            #if DEBUG
            print("Failed to apply scheduled Presence: \(error)")
            #endif
        }
    }

    private func end(_ active: ActivePresenceScheduleState, now: Date) async {
        if active.mode == .singleTime {
            _ = try? await ConfigUtility.shared.setActivePresenceScheduleState(nil)
            await PresenceScheduleBackgroundScheduler.shared.scheduleNextWake()
            return
        }

        do {
            if active.restorePolicy == .previousPresence, let previousPresence = active.previousPresence {
                var restoredPresence = previousPresence
                if active.resetsElapsedTimeOnRestore, restoredPresence.start != nil {
                    restoredPresence.start = now
                }
                try await DiscordSDKManager.shared.publishAppliedPresence(restoredPresence)
                _ = try await ConfigUtility.shared.setActiveCustomPresencePreset(id: active.previousPresetID)
                await PresenceLiveActivityController.shared.publish(
                    restoredPresence,
                    connectionStatus: LocalizationManager.shared.string(DiscordSDKManager.shared.dashboardStatus.localizationKey)
                )
            } else {
                try await DiscordSDKManager.shared.clearAppliedPresence(ifOwnedBy: .schedule)
                _ = try await ConfigUtility.shared.setActiveCustomPresencePreset(id: nil)
                await PresenceLiveActivityController.shared.end()
            }
            _ = try await ConfigUtility.shared.setActivePresenceScheduleState(nil)
            await PresenceScheduleBackgroundScheduler.shared.scheduleNextWake()
        } catch {
            #if DEBUG
            print("Failed to restore scheduled Presence: \(error)")
            #endif
        }
    }
}

@MainActor
public final class PresenceScheduleBackgroundScheduler {
    public static let shared = PresenceScheduleBackgroundScheduler()
    public static let taskIdentifier = "com.minepacu.CraftPresence.presence-schedule-refresh"

    private var isRegistered = false

    private init() {}

    public func register() {
        guard !isRegistered, !AutomationLaunchOptions.isUITesting else { return }
        isRegistered = true

        #if os(iOS) && canImport(BackgroundTasks)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            Task { @MainActor in
                await self.handle(task: task)
            }
        }
        #endif
    }

    public func scheduleNextWake(now: Date = Date()) async {
        guard !AutomationLaunchOptions.isUITesting else { return }
        let settings = await ConfigUtility.shared.currentSettings()
        guard let wakeDate = PresenceScheduleBackgroundPlan.nextWakeDate(in: settings, now: now) else {
            #if os(iOS) && canImport(BackgroundTasks)
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
            #endif
            return
        }

        #if os(iOS) && canImport(BackgroundTasks)
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = wakeDate
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            #if DEBUG
            print("Failed to schedule Presence background refresh: \(error)")
            #endif
        }
        #else
        _ = wakeDate
        #endif
    }

    #if os(iOS) && canImport(BackgroundTasks)
    private func handle(task: BGTask) async {
        task.expirationHandler = {
            Task { @MainActor in
                await self.scheduleNextWake()
            }
        }
        await PresenceScheduleManager.shared.evaluate()
        await PresencePriorityController.shared.enforceAppliedPresenceIfNeeded()
        await scheduleNextWake()
        task.setTaskCompleted(success: true)
    }
    #endif
}

private extension AppSettings {
    var currentAppliedPresencePayload: AppliedPresencePayload? {
        appliedPresence ?? appliedCustomPresence.map {
            AppliedPresencePayload(customPresencePreset: $0)
        }
    }
}
