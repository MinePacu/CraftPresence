//
//  SettingView.swift
//  CraftPresence
//
//  Created by Assistant on 2025-11-12.
//

import SwiftUI
import UniformTypeIdentifiers

/// Settings screen for localization, debug logging, and macOS menu bar presentation preferences.
struct SettingView: View {
    // Persist toggles with AppStorage so they survive restarts
    @AppStorage("debugLoggingEnabled") private var debugLoggingEnabled: Bool = false
    @AppStorage("menuBarOnlyEnabled") private var menuBarOnlyEnabled: Bool = false
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var presencePriorityEnabled: Bool = true
    @State private var presencePriorityReapplyIntervalSeconds: Int = PresencePriorityReapplyInterval.defaultSeconds
    @State private var presenceLiveActivityEnabled: Bool = true
    @State private var liveActivityContentOptions = LiveActivityContentOptions()
#if os(iOS)
    @State private var settingsExportDocument = SettingsBackupDocument()
    @State private var showingSettingsExporter = false
    @State private var showingSettingsImporter = false
    @State private var pendingSettingsImport: SettingsBackupFile?
    @State private var showingSettingsImportConfirmation = false
    @State private var settingsTransferErrorMessage: String?
    @State private var toastMessage: CPToastMessage?
#endif

    var body: some View {
        #if os(iOS)
        settingsContent
        #else
        NavigationStack {
            settingsContent
        }
        #endif
    }

    private var settingsContent: some View {
            CPSettingsPage {
                CPHeaderCard(
                    title: t("settings.title"),
                    subtitle: t("settings.description"),
                    systemImage: "gearshape",
                    tint: .gray
                )

                CPSettingsSection(t("settings.section.general")) {
                    CPSettingsRow(
                        title: t("settings.language"),
                        subtitle: t("settings.language.description"),
                        systemImage: "globe",
                        tint: .blue
                    ) {
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

                CPSettingsSection(t("settings.section.presence_control")) {
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

                    if presencePriorityEnabled {
                        CPSectionDivider()
                        CPSettingsRow(
                            title: t("settings.presence_priority.interval.title"),
                            subtitle: String(
                                format: t("settings.presence_priority.interval.description_format"),
                                presencePriorityReapplyIntervalSeconds
                            ),
                            systemImage: "clock.arrow.circlepath",
                            tint: .pink
                        ) {
                            HStack(spacing: 8) {
                                Text(
                                    String(
                                        format: t("settings.presence_priority.interval.value_format"),
                                        presencePriorityReapplyIntervalSeconds
                                    )
                                )
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()

                                Stepper(
                                    value: $presencePriorityReapplyIntervalSeconds.onChange(presencePriorityReapplyIntervalChanged),
                                    in: PresencePriorityReapplyInterval.minimumSeconds...PresencePriorityReapplyInterval.maximumSeconds,
                                    step: 10
                                ) {
                                    EmptyView()
                                }
                                .labelsHidden()
                            }
                        }
                        .accessibilityIdentifier("settings.presencePriority.interval")
                    }
                }

                #if os(iOS)
                CPSettingsSection(t("settings.section.live_activity")) {
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

                    if presenceLiveActivityEnabled {
                        CPSectionDivider()
                        CPSettingsRow(
                            title: t("settings.live_activity.content.summary.title"),
                            subtitle: t("settings.live_activity.content.summary.description"),
                            systemImage: "text.alignleft",
                            tint: .green
                        ) {
                            Toggle(
                                t("settings.live_activity.content.summary.title"),
                                isOn: liveActivityContentBinding(\.presenceSummary)
                            )
                            .labelsHidden()
                        }
                        .accessibilityIdentifier("settings.liveActivity.content.summary")

                        CPSectionDivider()
                        CPSettingsRow(
                            title: t("settings.live_activity.content.elapsed.title"),
                            subtitle: t("settings.live_activity.content.elapsed.description"),
                            systemImage: "timer",
                            tint: .green
                        ) {
                            Toggle(
                                t("settings.live_activity.content.elapsed.title"),
                                isOn: liveActivityContentBinding(\.elapsedTime)
                            )
                            .labelsHidden()
                        }
                        .accessibilityIdentifier("settings.liveActivity.content.elapsed")

                        CPSectionDivider()
                        CPSettingsRow(
                            title: t("settings.live_activity.content.discord_status.title"),
                            subtitle: t("settings.live_activity.content.discord_status.description"),
                            systemImage: "network",
                            tint: .green
                        ) {
                            Toggle(
                                t("settings.live_activity.content.discord_status.title"),
                                isOn: liveActivityContentBinding(\.discordStatus)
                            )
                            .labelsHidden()
                        }
                        .accessibilityIdentifier("settings.liveActivity.content.discordStatus")
                    }
                }
                #endif

#if os(iOS)
                CPSettingsSection(t("settings.section.settings_transfer")) {
                    CPSettingsRow(
                        title: t("settings.import_export.export.title"),
                        subtitle: t("settings.import_export.export.description"),
                        systemImage: "square.and.arrow.up",
                        tint: .indigo
                    ) {
                        Button {
                            prepareSettingsExport()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .accessibilityLabel(t("settings.import_export.export.action"))
                        }
                        .buttonStyle(.bordered)
                    }
                    .accessibilityIdentifier("settings.export")

                    CPSectionDivider()

                    CPSettingsRow(
                        title: t("settings.import_export.import.title"),
                        subtitle: t("settings.import_export.import.description"),
                        systemImage: "square.and.arrow.down",
                        tint: .teal
                    ) {
                        Button {
                            showingSettingsImporter = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .accessibilityLabel(t("settings.import_export.import.action"))
                        }
                        .buttonStyle(.bordered)
                    }
                    .accessibilityIdentifier("settings.import")
                }
#endif

                #if DEBUG
                CPSettingsSection(t("settings.section.debug"), footer: t("settings.debug_logging.footer")) {
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
                #endif
            }
            .navigationTitle(t("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
#if os(iOS)
            .fileExporter(
                isPresented: $showingSettingsExporter,
                document: settingsExportDocument,
                contentType: .json,
                defaultFilename: ConfigUtility.defaultSettingsBackupFilename()
            ) { result in
                handleSettingsExportCompletion(result)
            }
            .fileImporter(
                isPresented: $showingSettingsImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleSettingsImportSelection(result)
            }
            .alert(
                t("settings.import_export.import_confirm.title"),
                isPresented: $showingSettingsImportConfirmation,
                presenting: pendingSettingsImport
            ) { _ in
                Button(t("common.cancel"), role: .cancel) {
                    pendingSettingsImport = nil
                }
                Button(t("settings.import_export.import_confirm.action"), role: .destructive) {
                    confirmSettingsImport()
                }
            } message: { backup in
                Text(importConfirmationMessage(for: backup))
            }
            .alert(
                t("settings.import_export.error.title"),
                isPresented: Binding(
                    get: { settingsTransferErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            settingsTransferErrorMessage = nil
                        }
                    }
                )
            ) {
                Button(t("common.ok"), role: .cancel) {
                    settingsTransferErrorMessage = nil
                }
            } message: {
                Text(settingsTransferErrorMessage ?? "")
            }
            .cpToast($toastMessage)
#endif
            .onAppear {
                // 설정 화면 진입 시 현재 저장된 상태를 보장 적용
                applyMenuBarMode(menuBarOnlyEnabled)
                Task {
                    presencePriorityEnabled = await ConfigUtility.shared.isPresencePriorityEnabled()
                    presencePriorityReapplyIntervalSeconds = await ConfigUtility.shared.presencePriorityReapplyIntervalSeconds()
                    presenceLiveActivityEnabled = await ConfigUtility.shared.isPresenceLiveActivityEnabled()
                    liveActivityContentOptions = await ConfigUtility.shared.liveActivityContentOptions()
                }
            }
    }

#if os(iOS)
    private func prepareSettingsExport() {
        Task {
            do {
                let data = try await ConfigUtility.shared.exportSettingsBackup(platform: "iOS")
                await MainActor.run {
                    settingsExportDocument = SettingsBackupDocument(data: data)
                    showingSettingsExporter = true
                }
            } catch {
                await MainActor.run {
                    showSettingsTransferError(error)
                }
            }
        }
    }

    private func handleSettingsExportCompletion(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            toastMessage = CPToastMessage(text: t("settings.import_export.export.success"))
        case .failure(let error):
            guard !isUserCancellation(error) else { return }
            showSettingsTransferError(error)
        }
    }

    private func handleSettingsImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            loadPendingSettingsImport(from: url)
        case .failure(let error):
            guard !isUserCancellation(error) else { return }
            showSettingsTransferError(error)
        }
    }

    private func loadPendingSettingsImport(from url: URL) {
        do {
            let isSecurityScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isSecurityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let backup = try ConfigUtility.decodeSettingsBackup(from: data)
            pendingSettingsImport = backup
            showingSettingsImportConfirmation = true
        } catch {
            showSettingsTransferError(error)
        }
    }

    private func confirmSettingsImport() {
        guard let pendingSettingsImport else { return }

        Task {
            do {
                let imported = try await ConfigUtility.shared.importSettingsBackup(pendingSettingsImport)
                await localizationManager.load()
                await MainActor.run {
                    self.pendingSettingsImport = nil
                    presencePriorityEnabled = imported.presencePriorityEnabled
                    presencePriorityReapplyIntervalSeconds = imported.presencePriorityReapplyIntervalSeconds
                    presenceLiveActivityEnabled = imported.presenceLiveActivityEnabled
                    liveActivityContentOptions = imported.liveActivityContentOptions
                    toastMessage = CPToastMessage(text: t("settings.import_export.import.success"))
                }
            } catch {
                await MainActor.run {
                    showSettingsTransferError(error)
                }
            }
        }
    }

    private func importConfirmationMessage(for backup: SettingsBackupFile) -> String {
        let date = backup.exportedAt.formatted(date: .abbreviated, time: .shortened)
        return String(
            format: t("settings.import_export.import_confirm.message_format"),
            backup.platform,
            date
        )
    }

    private func showSettingsTransferError(_ error: Error) {
        settingsTransferErrorMessage = error.localizedDescription
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }
#endif

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

    /// Saves the interval between periodic app-owned Presence reassertions.
    private func presencePriorityReapplyIntervalChanged(_ seconds: Int) {
        let clampedSeconds = PresencePriorityReapplyInterval.clamped(seconds)
        presencePriorityReapplyIntervalSeconds = clampedSeconds
        Task {
            do {
                _ = try await ConfigUtility.shared.setPresencePriorityReapplyIntervalSeconds(clampedSeconds)
            } catch {
                presencePriorityReapplyIntervalSeconds = await ConfigUtility.shared.presencePriorityReapplyIntervalSeconds()
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

    #if os(iOS)
    private func liveActivityContentBinding(
        _ keyPath: WritableKeyPath<LiveActivityContentOptions, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { liveActivityContentOptions[keyPath: keyPath] },
            set: { newValue in
                var updated = liveActivityContentOptions
                updated[keyPath: keyPath] = newValue
                liveActivityContentOptions = updated
                liveActivityContentOptionsChanged(updated)
            }
        )
    }

    private func liveActivityContentOptionsChanged(_ options: LiveActivityContentOptions) {
        Task {
            do {
                _ = try await ConfigUtility.shared.setLiveActivityContentOptions(options)
                if presenceLiveActivityEnabled,
                   let appliedPresence = await ConfigUtility.shared.currentAppliedCustomPresence() {
                    await PresenceLiveActivityController.shared.publish(
                        appliedPresence,
                        connectionStatus: t(DiscordSDKManager.shared.dashboardStatus.localizationKey)
                    )
                }
            } catch {
                liveActivityContentOptions = await ConfigUtility.shared.liveActivityContentOptions()
            }
        }
    }
    #endif

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

#if os(iOS)
private struct SettingsBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
#endif

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
