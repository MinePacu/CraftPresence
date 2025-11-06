import Foundation
import UniformTypeIdentifiers

// MARK: - Settings Model
public struct AppSettings: Codable, Sendable, Equatable {
    // 사용자 추가 프로그램의 bundleID 목록
    public var bundleIDs: [String] = []
    
    init() { }

    // 향후 다른 설정을 쉽게 추가하기 위한 예시 (주석 처리)
    // public var enableRichPresence: Bool = true
    // public var pollingInterval: Double = 2.0

    // Explicit nonisolated Codable to avoid main-actor isolated conformance issues in Swift 6
    private enum CodingKeys: String, CodingKey {
        case bundleIDs
    }

    nonisolated public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleIDs = try container.decodeIfPresent([String].self, forKey: .bundleIDs) ?? []
    }

    nonisolated public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleIDs, forKey: .bundleIDs)
    }
}

// MARK: - Config Utility (Actor for thread-safety)
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
            // 최초 저장으로 파일/폴더 생성
            try? persist()
        }
    }

    // MARK: - Public API

    public func currentSettings() -> AppSettings {
        settings
    }

    @discardableResult
    public func setSettings(_ newValue: AppSettings) async throws -> AppSettings {
        self.settings = newValue
        try persist()
        return settings
    }

    // MARK: BundleID helpers

    @discardableResult
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
    public func removeBundleID(_ id: String) async throws -> AppSettings {
        let before = settings.bundleIDs
        settings.bundleIDs.removeAll { $0 == id }
        if settings.bundleIDs != before {
            try persist()
        }
        return settings
    }

    public func containsBundleID(_ id: String) -> Bool {
        settings.bundleIDs.contains(id)
    }

    // MARK: - Persistence

    private func persist() throws {
        let data = try encoder.encode(settings)
        try ensureParentDirectoryExists(for: fileURL)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func ensureParentDirectoryExists(for url: URL) throws {
        let dir = url.deletingLastPathComponent()
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private static func defaultSettingsURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = (Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String) ?? "CraftPresence"
        return base.appendingPathComponent(bundleID, isDirectory: true)
                   .appendingPathComponent("settings.json")
    }
}

