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
    @State private var presencePriorityEnabled: Bool = true
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(t("settings.title"))
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("settings.title")

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    settingsSection(t("settings.section.general")) {
                        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 12) {
                            GridRow {
                                Text(t("settings.language"))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .gridColumnAlignment(.trailing)

                                Picker(t("settings.language"), selection: languageBinding) {
                                    ForEach(AppLanguage.allCases) { language in
                                        Text(languageLabel(for: language)).tag(language)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 160, alignment: .leading)
                            }
                        }

                        Toggle(isOn: $menuBarOnlyEnabled.onChange(menuBarToggleChanged)) {
                            settingLabel(
                                title: t("settings.menu_bar_only.title"),
                                description: t("settings.menu_bar_only.description")
                            )
                        }
                        .help(t("settings.menu_bar_only.help"))

                        Toggle(isOn: $presencePriorityEnabled.onChange(presencePriorityToggleChanged)) {
                            settingLabel(
                                title: t("settings.presence_priority.title"),
                                description: t("settings.presence_priority.description")
                            )
                        }
                        .help(t("settings.presence_priority.help"))
                    }

                    #if DEBUG
                    settingsSection(t("settings.section.debug")) {
                        Toggle(isOn: $debugLoggingEnabled) {
                            settingLabel(
                                title: t("settings.debug_logging.title"),
                                description: t("settings.debug_logging.description")
                            )
                        }

                        Text(t("settings.debug_logging.footer"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    #endif
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("settings.root")
        .onAppear {
            // 설정 화면 진입 시 현재 저장된 상태를 보장 적용
            applyMenuBarMode(menuBarOnlyEnabled)
        }
        .task {
            presencePriorityEnabled = await ConfigUtility.shared.isPresencePriorityEnabled()
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func settingLabel(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body.weight(.semibold))
            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Responds to menu bar mode changes immediately so the app chrome matches the stored preference.
    private func menuBarToggleChanged(_ newValue: Bool) {
        applyMenuBarMode(newValue)
    }

    /// Persists priority changes and immediately enforces the saved Presence when re-enabled.
    private func presencePriorityToggleChanged(_ newValue: Bool) {
        Task {
            do {
                _ = try await ConfigUtility.shared.setPresencePriorityEnabled(newValue)
                if newValue {
                    PresencePriorityController.shared.start()
                    await PresencePriorityController.shared.enforceAppliedPresenceIfNeeded()
                } else {
                    PresencePriorityController.shared.stop()
                }
            } catch {
                presencePriorityEnabled = await ConfigUtility.shared.isPresencePriorityEnabled()
            }
        }
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
