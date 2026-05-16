import Foundation
import UniformTypeIdentifiers

// MARK: - Settings Model
/// Persisted root settings model stored on disk for tracked apps, localization, and per-program presence options.
public struct AppSettings: Codable, Sendable, Equatable {
    // 사용자 추가 프로그램의 bundleID 목록
    public var bundleIDs: [String] = []
    public var programSettings: [String: ProgramPresenceSettings] = [:]
    public var presencePresets: [PresencePreset] = PresencePreset.defaults
    public var activePresencePresetID: UUID?
    public var appliedPresence: AppliedPresencePayload?
    public var preferredLanguage: AppLanguage = .system
    public var presencePriorityEnabled: Bool = true
    
    nonisolated init() { }

    // 향후 다른 설정을 쉽게 추가하기 위한 예시 (주석 처리)
    // public var enableRichPresence: Bool = true
    // public var pollingInterval: Double = 2.0

    // Explicit nonisolated Codable to avoid main-actor isolated conformance issues in Swift 6
    private enum CodingKeys: String, CodingKey {
        case bundleIDs
        case programSettings
        case presencePresets
        case customPresencePresets
        case activePresencePresetID
        case activeCustomPresencePresetID
        case appliedPresence
        case preferredLanguage
        case presencePriorityEnabled
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleIDs = try container.decodeIfPresent([String].self, forKey: .bundleIDs) ?? []
        self.programSettings = try container.decodeIfPresent([String: ProgramPresenceSettings].self, forKey: .programSettings) ?? [:]
        self.presencePresets = try container.decodeIfPresent([PresencePreset].self, forKey: .presencePresets)
            ?? container.decodeIfPresent([PresencePreset].self, forKey: .customPresencePresets)
            ?? PresencePreset.defaults
        self.activePresencePresetID = try container.decodeIfPresent(UUID.self, forKey: .activePresencePresetID)
            ?? container.decodeIfPresent(UUID.self, forKey: .activeCustomPresencePresetID)
        self.appliedPresence = try container.decodeIfPresent(AppliedPresencePayload.self, forKey: .appliedPresence)
        self.preferredLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .preferredLanguage) ?? .system
        self.presencePriorityEnabled = try container.decodeIfPresent(Bool.self, forKey: .presencePriorityEnabled) ?? true
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleIDs, forKey: .bundleIDs)
        try container.encode(programSettings, forKey: .programSettings)
        try container.encode(presencePresets, forKey: .presencePresets)
        try container.encode(presencePresets, forKey: .customPresencePresets)
        try container.encodeIfPresent(activePresencePresetID, forKey: .activePresencePresetID)
        try container.encodeIfPresent(activePresencePresetID, forKey: .activeCustomPresencePresetID)
        try container.encodeIfPresent(appliedPresence, forKey: .appliedPresence)
        try container.encode(preferredLanguage, forKey: .preferredLanguage)
        try container.encode(presencePriorityEnabled, forKey: .presencePriorityEnabled)
    }
}

/// Versioned JSON backup envelope used for cross-platform settings import and export.
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

    nonisolated public func importSummary() -> SettingsImportSummary {
        SettingsImportSummary(
            schemaVersion: schemaVersion,
            platform: platform,
            exportedAt: exportedAt,
            presetCount: settings.presencePresets.count,
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
    case missingActivePreset(UUID)
    case duplicateBundleID(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "Unsupported settings backup schema version: \(version)."
        case .duplicatePresetID(let id):
            return "The settings backup contains a duplicate preset ID: \(id.uuidString)."
        case .missingActivePreset(let id):
            return "The settings backup references a missing active preset ID: \(id.uuidString)."
        case .duplicateBundleID(let id):
            return "The settings backup contains a duplicate bundle ID: \(id)."
        }
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

/// Shared Rich Presence preset schema used by Android, iOS, and macOS.
public struct PresencePreset: Codable, Identifiable, Sendable, Equatable {
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
    public var pausedElapsedDuration: TimeInterval?
    public var resetsElapsedTimeOnPublish: Bool = true
    public var usesParty: Bool = false
    public var partyCurrent: Int = 1
    public var partyMax: Int = 1
    public var isDefault: Bool = false
    public var updatedAt: Date = defaultUpdatedAt

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
        case pausedElapsedDuration
        case resetsElapsedTimeOnPublish
        case usesParty
        case partyCurrent
        case partyMax
        case isDefault
        case updatedAt
    }

    nonisolated public init() {}

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
        pausedElapsedDuration: TimeInterval? = nil,
        resetsElapsedTimeOnPublish: Bool = true,
        usesParty: Bool = false,
        partyCurrent: Int = 1,
        partyMax: Int = 1,
        isDefault: Bool = false,
        updatedAt: Date = PresencePreset.defaultUpdatedAt
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
        self.pausedElapsedDuration = pausedElapsedDuration
        self.resetsElapsedTimeOnPublish = resetsElapsedTimeOnPublish
        self.usesParty = usesParty
        self.partyCurrent = partyCurrent
        self.partyMax = partyMax
        self.isDefault = isDefault
        self.updatedAt = updatedAt
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            title: try container.decodeIfPresent(String.self, forKey: .title) ?? "",
            activityType: try container.decodeIfPresent(ProgramPresenceSettings.ActivityType.self, forKey: .activityType) ?? .playing,
            details: try container.decodeIfPresent(String.self, forKey: .details) ?? "",
            state: try container.decodeIfPresent(String.self, forKey: .state) ?? "",
            largeImageKey: try container.decodeIfPresent(String.self, forKey: .largeImageKey) ?? "",
            largeImageText: try container.decodeIfPresent(String.self, forKey: .largeImageText) ?? "",
            smallImageKey: try container.decodeIfPresent(String.self, forKey: .smallImageKey) ?? "",
            smallImageText: try container.decodeIfPresent(String.self, forKey: .smallImageText) ?? "",
            usesElapsedTime: try container.decodeIfPresent(Bool.self, forKey: .usesElapsedTime) ?? true,
            elapsedStartDate: try container.decodeIfPresent(Date.self, forKey: .elapsedStartDate),
            pausedElapsedDuration: try container.decodeIfPresent(TimeInterval.self, forKey: .pausedElapsedDuration),
            resetsElapsedTimeOnPublish: try container.decodeIfPresent(Bool.self, forKey: .resetsElapsedTimeOnPublish) ?? true,
            usesParty: try container.decodeIfPresent(Bool.self, forKey: .usesParty) ?? false,
            partyCurrent: try container.decodeIfPresent(Int.self, forKey: .partyCurrent) ?? 1,
            partyMax: try container.decodeIfPresent(Int.self, forKey: .partyMax) ?? 1,
            isDefault: try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false,
            updatedAt: try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Self.defaultUpdatedAt
        )
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
        try container.encodeIfPresent(pausedElapsedDuration, forKey: .pausedElapsedDuration)
        try container.encode(resetsElapsedTimeOnPublish, forKey: .resetsElapsedTimeOnPublish)
        try container.encode(usesParty, forKey: .usesParty)
        try container.encode(partyCurrent, forKey: .partyCurrent)
        try container.encode(partyMax, forKey: .partyMax)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    nonisolated public static let defaultUpdatedAt = Date(timeIntervalSince1970: 1_778_198_400)

    nonisolated public var pausedElapsedDurationForDisplay: TimeInterval? {
        guard usesElapsedTime,
              !resetsElapsedTimeOnPublish,
              let pausedElapsedDuration else {
            return nil
        }
        return pausedElapsedDuration
    }

    nonisolated public func elapsedStartDateForPublish(now: Date = Date()) -> Date? {
        guard usesElapsedTime else { return nil }
        guard !resetsElapsedTimeOnPublish else { return now }
        return elapsedStartDate ?? now
    }

    nonisolated public func pausedElapsedDurationForPublish(now: Date = Date()) -> TimeInterval? {
        guard usesElapsedTime,
              !resetsElapsedTimeOnPublish,
              let elapsedStartDate else {
            return nil
        }
        return max(0, now.timeIntervalSince(elapsedStartDate))
    }

    nonisolated public static let defaults: [PresencePreset] = [
        PresencePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "Coding",
            activityType: .playing,
            details: "Building CraftPresence",
            state: "Writing code",
            largeImageKey: "code",
            largeImageText: "Coding",
            isDefault: true
        ),
        PresencePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Studying",
            activityType: .watching,
            details: "Studying",
            state: "Reviewing notes",
            largeImageKey: "study",
            largeImageText: "Study session",
            isDefault: true
        ),
        PresencePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            title: "Focus",
            activityType: .playing,
            details: "Deep work session",
            state: "Staying focused",
            largeImageKey: "focus",
            largeImageText: "Focus mode",
            isDefault: true
        ),
        PresencePreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            title: "Gaming",
            activityType: .playing,
            details: "Gaming session",
            state: "In game",
            largeImageKey: "gaming",
            largeImageText: "Gaming",
            isDefault: true
        ),
        PresencePreset(
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

/// Discord Rich Presence payload last successfully applied by CraftPresence.
public enum AppliedPresenceSource: String, Codable, Sendable, Equatable {
    case manual
    case program
    case appleMusic
    case xcode
    case schedule
}

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
        self.source = source
    }

    nonisolated public init(presencePreset preset: PresencePreset, source: AppliedPresenceSource = .manual) {
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
            start: preset.usesElapsedTime ? (preset.elapsedStartDate ?? preset.elapsedStartDateForPublish()) : nil,
            activityType: preset.activityType,
            source: source
        )
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decodeIfPresent(String.self, forKey: .name) ?? "CraftPresence",
            state: try container.decodeIfPresent(String.self, forKey: .state),
            details: try container.decodeIfPresent(String.self, forKey: .details),
            largeImageKey: try container.decodeIfPresent(String.self, forKey: .largeImageKey),
            largeImageText: try container.decodeIfPresent(String.self, forKey: .largeImageText),
            smallImageKey: try container.decodeIfPresent(String.self, forKey: .smallImageKey),
            smallImageText: try container.decodeIfPresent(String.self, forKey: .smallImageText),
            partyID: try container.decodeIfPresent(String.self, forKey: .partyID),
            partyCurrent: try container.decodeIfPresent(Int.self, forKey: .partyCurrent),
            partyMax: try container.decodeIfPresent(Int.self, forKey: .partyMax),
            start: try container.decodeIfPresent(Date.self, forKey: .start),
            end: try container.decodeIfPresent(Date.self, forKey: .end),
            activityType: try container.decodeIfPresent(ProgramPresenceSettings.ActivityType.self, forKey: .activityType) ?? .playing,
            source: try container.decodeIfPresent(AppliedPresenceSource.self, forKey: .source) ?? .manual
        )
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(details, forKey: .details)
        try container.encodeIfPresent(largeImageKey, forKey: .largeImageKey)
        try container.encodeIfPresent(largeImageText, forKey: .largeImageText)
        try container.encodeIfPresent(smallImageKey, forKey: .smallImageKey)
        try container.encodeIfPresent(smallImageText, forKey: .smallImageText)
        try container.encodeIfPresent(partyID, forKey: .partyID)
        try container.encodeIfPresent(partyCurrent, forKey: .partyCurrent)
        try container.encodeIfPresent(partyMax, forKey: .partyMax)
        try container.encodeIfPresent(start, forKey: .start)
        try container.encodeIfPresent(end, forKey: .end)
        try container.encode(activityType, forKey: .activityType)
        try container.encode(source, forKey: .source)
    }

    nonisolated private static func trimmed(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == true ? nil : trimmed
    }
}

public extension AppSettings {
    @discardableResult
    nonisolated mutating func clearAppliedPresence(ifOwnedBy source: AppliedPresenceSource) -> Bool {
        guard appliedPresence?.source == source else { return false }
        appliedPresence = nil
        return true
    }

    @discardableResult
    nonisolated mutating func duplicatePresencePreset(id: UUID, title: String? = nil, now: Date = Date()) -> PresencePreset? {
        guard let source = presencePresets.first(where: { $0.id == id }) else { return nil }
        var copy = source
        copy.id = UUID()
        copy.title = title ?? source.title
        copy.isDefault = false
        copy.updatedAt = now
        presencePresets.append(copy)
        return copy
    }

    nonisolated mutating func removePresencePreset(id: UUID) {
        let isRemovingActivePreset = activePresencePresetID == id
        presencePresets.removeAll { $0.id == id }
        if isRemovingActivePreset {
            activePresencePresetID = nil
        }
        if isRemovingActivePreset || appliedPresence?.partyID == "preset:\(id.uuidString)" {
            appliedPresence = nil
        }
    }

    @discardableResult
    nonisolated mutating func restoreDefaultPresencePresets() -> Bool {
        let existingIDs = Set(presencePresets.map(\.id))
        let missingDefaults = PresencePreset.defaults.filter { !existingIDs.contains($0.id) }
        guard !missingDefaults.isEmpty else { return false }
        presencePresets.append(contentsOf: missingDefaults)
        return true
    }
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

    /// Platform value written into exported settings backup metadata.
    public nonisolated static var currentBackupPlatform: String { "macOS" }

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

        let bundleIDs = backup.settings.bundleIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let duplicateBundleID = bundleIDs.first(where: { id in !id.isEmpty && bundleIDs.filter { $0 == id }.count > 1 }) {
            throw SettingsBackupError.duplicateBundleID(duplicateBundleID)
        }

        let presetIDs = backup.settings.presencePresets.map(\.id)
        let uniquePresetIDs = Set(presetIDs)
        if presetIDs.count != uniquePresetIDs.count,
           let duplicateID = presetIDs.first(where: { id in presetIDs.filter { $0 == id }.count > 1 }) {
            throw SettingsBackupError.duplicatePresetID(duplicateID)
        }

        if let activeID = backup.settings.activePresencePresetID,
           !uniquePresetIDs.contains(activeID) {
            throw SettingsBackupError.missingActivePreset(activeID)
        }
    }

    /// Returns the data users can save as a `.craftpresence.json` settings backup file.
    public func exportSettingsBackup(
        exportedAt: Date = Date(),
        platform: String = ConfigUtility.currentBackupPlatform,
        appVersion: String? = ConfigUtility.currentAppVersion,
        buildNumber: String? = ConfigUtility.currentBuildNumber,
        platformExtensions: [String: String] = [:]
    ) throws -> Data {
        try ConfigUtility.encodeSettingsBackup(
            settings: settings,
            exportedAt: exportedAt,
            platform: platform,
            appVersion: appVersion,
            buildNumber: buildNumber,
            platformExtensions: platformExtensions
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
    /// Decodes, validates, and imports a settings backup atomically.
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

    // MARK: Presence Presets

    /// Returns all saved Rich Presence presets.
    public func presencePresets() -> [PresencePreset] {
        settings.presencePresets
    }

    /// Returns the currently active Presence preset when it still exists in settings.
    public func activePresencePreset() -> PresencePreset? {
        guard let id = settings.activePresencePresetID else { return nil }
        return settings.presencePresets.first { $0.id == id }
    }

    @discardableResult
    /// Updates an existing preset or appends it when it is new.
    public func upsertPresencePreset(_ preset: PresencePreset) async throws -> PresencePreset {
        if let index = settings.presencePresets.firstIndex(where: { $0.id == preset.id }) {
            settings.presencePresets[index] = preset
        } else {
            settings.presencePresets.append(preset)
        }
        try persist()
        return preset
    }

    @discardableResult
    /// Creates a copy of a preset with a new identifier so users can edit it independently.
    public func duplicatePresencePreset(id: UUID, title: String? = nil) async throws -> PresencePreset? {
        guard let copy = settings.duplicatePresencePreset(id: id, title: title) else { return nil }
        try persist()
        return copy
    }

    @discardableResult
    /// Removes a preset and clears active state if that preset was published.
    public func removePresencePreset(id: UUID) async throws -> AppSettings {
        settings.removePresencePreset(id: id)
        try persist()
        return settings
    }

    @discardableResult
    /// Stores which preset is currently active.
    public func setActivePresencePreset(id: UUID?) async throws -> AppSettings {
        settings.activePresencePresetID = id
        try persist()
        return settings
    }

    @discardableResult
    /// Stores the latest app-owned Presence payload that was actually published to Discord.
    public func setAppliedPresence(_ payload: AppliedPresencePayload?) async throws -> AppSettings {
        settings.appliedPresence = payload
        try persist()
        return settings
    }

    /// Returns the latest app-owned Presence payload that should be considered authoritative.
    public func currentAppliedPresence() -> AppliedPresencePayload? {
        settings.appliedPresence
    }

    /// Returns whether CraftPresence should reapply its last app-owned Presence while it remains running.
    public func isPresencePriorityEnabled() -> Bool {
        settings.presencePriorityEnabled
    }

    @discardableResult
    /// Enables or disables runtime reapplication of the last app-owned Presence.
    public func setPresencePriorityEnabled(_ enabled: Bool) async throws -> AppSettings {
        settings.presencePriorityEnabled = enabled
        try persist()
        return settings
    }

    @discardableResult
    /// Clears the latest app-owned Presence only when it belongs to the given source.
    public func clearAppliedPresence(ifOwnedBy source: AppliedPresenceSource) async throws -> AppSettings {
        if settings.clearAppliedPresence(ifOwnedBy: source) {
            try persist()
        }
        return settings
    }

    @discardableResult
    /// Restores only missing built-in Presence presets while leaving user edits and deletions intact.
    public func restoreDefaultPresencePresets() async throws -> AppSettings {
        guard settings.restoreDefaultPresencePresets() else { return settings }
        try persist()
        return settings
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
        sanitized.appliedPresence = nil
        sanitized.activePresencePresetID = nil
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
