import Foundation
import Combine
import SwiftUI

@MainActor
/// Centralized localization state holder that applies the user's preferred in-app language.
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published private(set) var language: AppLanguage = .system

    /// Locale injected into SwiftUI so built-in formatters and date rendering follow the selected language.
    var locale: Locale {
        switch language {
        case .system:
            return .autoupdatingCurrent
        case .korean:
            return Locale(identifier: AppLanguage.korean.rawValue)
        case .english:
            return Locale(identifier: AppLanguage.english.rawValue)
        case .japanese:
            return Locale(identifier: AppLanguage.japanese.rawValue)
        }
    }

    private init() {}

    /// Loads the preferred language from persisted settings during app startup.
    func load() async {
        let settings = await ConfigUtility.shared.currentSettings()
        language = settings.preferredLanguage
    }

    /// Persists a new language selection and updates dependent UI on the main actor.
    func updateLanguage(_ newLanguage: AppLanguage) async {
        guard language != newLanguage else { return }

        var settings = await ConfigUtility.shared.currentSettings()
        settings.preferredLanguage = newLanguage

        do {
            _ = try await ConfigUtility.shared.setSettings(settings)
            language = newLanguage
            #if os(macOS)
            LSUIElementController.shared.refreshLocalizedMenu()
            #endif
        } catch {
            #if DEBUG
            print("Failed to update language setting: \(error)")
            #endif
        }
    }

    /// Resolves a localized string for the currently active language, falling back to the key when missing.
    func string(_ key: String) -> String {
        let bundle = localizedBundle(for: language)
        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }

    private func localizedBundle(for language: AppLanguage) -> Bundle {
        switch language {
        case .system:
            return .main
        case .korean, .english, .japanese:
            guard
                let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
                let bundle = Bundle(path: path)
            else {
                return .main
            }
            return bundle
        }
    }
}
