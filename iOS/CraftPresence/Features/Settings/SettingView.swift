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
    @State private var presencePriorityEnabled: Bool = true
    @State private var presenceLiveActivityEnabled: Bool = true

    var body: some View {
        NavigationStack {
            CPSettingsPage {
                CPHeaderCard(
                    title: t("settings.title"),
                    subtitle: t("settings.presence_priority.description"),
                    systemImage: "gearshape",
                    tint: .gray
                )

                CPGroupedSection {
                    CPSettingsRow(title: t("settings.language"), systemImage: "globe", tint: .blue) {
                        Picker(t("settings.language"), selection: languageBinding) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(languageLabel(for: language)).tag(language)
                            }
                        }
                        .labelsHidden()
                    }

#if os(macOS)
                    CPSectionDivider()
                    CPSettingsRow(
                        title: t("settings.menu_bar_only.title"),
                        subtitle: t("settings.menu_bar_only.description"),
                        systemImage: "menubar.rectangle",
                        tint: .purple
                    ) {
                        Toggle(t("settings.menu_bar_only.title"), isOn: $menuBarOnlyEnabled.onChange(menuBarToggleChanged))
                            .labelsHidden()
                    }
                    .help(t("settings.menu_bar_only.help"))
#endif
                }

                CPGroupedSection {
                    CPSettingsRow(
                        title: t("settings.presence_priority.title"),
                        subtitle: t("settings.presence_priority.description"),
                        systemImage: "paperplane.fill",
                        tint: .pink
                    ) {
                        Toggle(t("settings.presence_priority.title"), isOn: $presencePriorityEnabled.onChange(presencePriorityToggleChanged))
                            .labelsHidden()
                    }
                    .help(t("settings.presence_priority.help"))
                    .accessibilityIdentifier("settings.presencePriority")

                    #if os(iOS)
                    CPSectionDivider()
                    CPSettingsRow(
                        title: t("settings.live_activity.title"),
                        subtitle: t("settings.live_activity.description"),
                        systemImage: "iphone.gen3",
                        tint: .green
                    ) {
                        Toggle(t("settings.live_activity.title"), isOn: $presenceLiveActivityEnabled.onChange(liveActivityToggleChanged))
                            .labelsHidden()
                    }
                    .help(t("settings.live_activity.help"))
                    .accessibilityIdentifier("settings.liveActivity")
                    #endif
                }

                #if DEBUG
                CPGroupedSection {
                    CPSettingsRow(
                        title: t("settings.debug_logging.title"),
                        subtitle: t("settings.debug_logging.description"),
                        systemImage: "ladybug",
                        tint: .orange
                    ) {
                        Toggle(t("settings.debug_logging.title"), isOn: $debugLoggingEnabled)
                            .labelsHidden()
                    }
                }

                Text(t("settings.debug_logging.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                #endif
            }
            .navigationTitle(t("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // 설정 화면 진입 시 현재 저장된 상태를 보장 적용
                applyMenuBarMode(menuBarOnlyEnabled)
                Task {
                    presencePriorityEnabled = await ConfigUtility.shared.isPresencePriorityEnabled()
                    presenceLiveActivityEnabled = await ConfigUtility.shared.isPresenceLiveActivityEnabled()
                }
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

    /// Saves whether the app should reapply its own Presence after another client changes it.
    private func presencePriorityToggleChanged(_ enabled: Bool) {
        Task {
            do {
                _ = try await ConfigUtility.shared.setPresencePriorityEnabled(enabled)
                if enabled {
                    await PresencePriorityController.shared.enforceAppliedPresenceIfNeeded()
                }
            } catch {
                presencePriorityEnabled.toggle()
            }
        }
    }

    /// Saves whether ActivityKit should mirror the currently published Presence.
    private func liveActivityToggleChanged(_ enabled: Bool) {
        Task {
            do {
                _ = try await ConfigUtility.shared.setPresenceLiveActivityEnabled(enabled)
                if enabled, let appliedPresence = await ConfigUtility.shared.currentAppliedCustomPresence() {
                    await PresenceLiveActivityController.shared.publish(
                        appliedPresence,
                        connectionStatus: t(DiscordSDKManager.shared.dashboardStatus.localizationKey)
                    )
                } else {
                    await PresenceLiveActivityController.shared.end()
                }
            } catch {
                presenceLiveActivityEnabled.toggle()
            }
        }
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
        case .japanese:
            return t("settings.language.japanese")
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
