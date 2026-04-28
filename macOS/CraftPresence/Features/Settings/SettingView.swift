//
//  SettingView.swift
//  CraftPresence
//
//  Created by Assistant on 2025-11-12.
//

import SwiftUI

/// Settings screen for localization, debug logging, and macOS menu bar presentation preferences.
struct SettingView: View {
    // Persist toggles with AppStorage so they survive restarts
    @AppStorage("debugLoggingEnabled") private var debugLoggingEnabled: Bool = false
    @AppStorage("menuBarOnlyEnabled") private var menuBarOnlyEnabled: Bool = false
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(t("settings.section.general"))) {
                    Picker(t("settings.language"), selection: languageBinding) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(languageLabel(for: language)).tag(language)
                        }
                    }

                    Toggle(isOn: $menuBarOnlyEnabled.onChange(menuBarToggleChanged)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t("settings.menu_bar_only.title"))
                            Text(t("settings.menu_bar_only.description"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .help(t("settings.menu_bar_only.help"))
                }

                #if DEBUG
                Section(header: Text(t("settings.section.debug"))) {
                    Toggle(isOn: $debugLoggingEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t("settings.debug_logging.title"))
                            Text(t("settings.debug_logging.description"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(footer: Text(t("settings.debug_logging.footer"))) {
                    EmptyView()
                }
                #endif
            }
            .navigationTitle(t("settings.title"))
            .onAppear {
                // 설정 화면 진입 시 현재 저장된 상태를 보장 적용
                applyMenuBarMode(menuBarOnlyEnabled)
            }
        }
    }

    /// Responds to menu bar mode changes immediately so the app chrome matches the stored preference.
    private func menuBarToggleChanged(_ newValue: Bool) {
        applyMenuBarMode(newValue)
    }

    /// Applies the current menu-bar-only mode using the shared AppKit controller on macOS.
    private func applyMenuBarMode(_ enabled: Bool) {
        #if os(macOS)
        if enabled {
            LSUIElementController.shared.enableMenuBarOnly()
        } else {
            LSUIElementController.shared.disableMenuBarOnly()
        }
        #endif
    }

    /// Two-way binding that saves language changes asynchronously through the localization manager.
    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { localizationManager.language },
            set: { newLanguage in
                Task {
                    await localizationManager.updateLanguage(newLanguage)
                }
            }
        )
    }

    /// Returns the user-facing label shown for each supported language option.
    private func languageLabel(for language: AppLanguage) -> String {
        switch language {
        case .system:
            return t("settings.language.system")
        case .korean:
            return t("settings.language.korean")
        case .english:
            return t("settings.language.english")
        }
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

// MARK: - Binding helper
private extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}

#Preview {
    SettingView()
}
