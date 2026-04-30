import Foundation

enum AutomationLaunchOptions {
    private static let environment = ProcessInfo.processInfo.environment

    static var isUITesting: Bool {
        environment["CRAFTPRESENCE_UI_TEST_MODE"] == "1"
    }

    static var isAccessibilityTrusted: Bool {
        environment["CRAFTPRESENCE_ACCESSIBILITY_TRUSTED"] == "1"
    }

    static var shouldDisableProgramDetector: Bool {
        environment["CRAFTPRESENCE_DISABLE_PROGRAM_DETECTOR"] == "1"
    }

    static var activeAppName: String? {
        trimmedValue(for: "CRAFTPRESENCE_ACTIVE_APP_NAME")
    }

    static var activeBundleID: String? {
        trimmedValue(for: "CRAFTPRESENCE_ACTIVE_BUNDLE_ID")
    }

    static var activeWindowTitle: String? {
        trimmedValue(for: "CRAFTPRESENCE_ACTIVE_WINDOW_TITLE")
    }

    static var seedBundleIDs: [String] {
        listValue(for: "CRAFTPRESENCE_SEED_BUNDLE_IDS")
    }

    static var settingsPathOverride: String? {
        trimmedValue(for: "CRAFTPRESENCE_SETTINGS_PATH")
    }

    private static func trimmedValue(for key: String) -> String? {
        environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private static func listValue(for key: String) -> [String] {
        guard let rawValue = environment[key] else { return [] }

        return rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
