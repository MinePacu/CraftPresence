import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

/// Management screen for selecting which applications should publish Discord Rich Presence.
struct ProgramsView: View {
    @Binding var programIDs: [String]
    @Binding var isLoadingPrograms: Bool
    @Binding var showingProgramSettings: Bool
    @Binding var selectedProgramIDForSettings: String?
    @EnvironmentObject private var localizationManager: LocalizationManager

    #if os(macOS)
    @State private var appMetadataCache: [String: ProgramDisplayInfo] = [:]
    #endif
    @State private var programSettingsCache: [String: ProgramPresenceSettings] = [:]
    @State private var operationErrorMessage: String?
    @State private var pendingRemovalBundleID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("programs.title"), systemImage: "list.bullet.rectangle")
                .font(.title2).bold()
                .accessibilityIdentifier("programs.title")
            Text(t("programs.subtitle"))
                .foregroundStyle(.secondary)
            Text(t("programs.description"))
                .font(.footnote)
                .foregroundStyle(.tertiary)

            if let operationErrorMessage {
                Label(operationErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("programs.operationError")
            }

            // Add buttons
            HStack(spacing: 8) {
                Button {
                    #if os(macOS)
                    let panel = NSOpenPanel()
                    panel.title = t("programs.select_application")
                    panel.message = t("programs.select_application_message")
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    panel.allowedContentTypes = [.application]
                    panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
                    if panel.runModal() == .OK, let url = panel.url {
                        if let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier {
                            Task {
                                do {
                                    let updated = try await ConfigUtility.shared.addBundleID(bundleID)
                                    await MainActor.run {
                                        operationErrorMessage = nil
                                        programIDs = updated.bundleIDs
                                    }
                                } catch {
                                    await MainActor.run {
                                        operationErrorMessage = error.localizedDescription
                                    }
                                }
                            }
                        } else {
                            operationErrorMessage = t("programs.bundle_id_unavailable")
                        }
                    }
                    #else
                    operationErrorMessage = "Add Program is only supported on macOS in this build."
                    #endif
                } label: {
                    Label(t("programs.add_program"), systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("programs.add")

                Button {
                    Task {
                        do {
                            let updated = try await ConfigUtility.shared.addBundleID("com.apple.Music")
                            await MainActor.run {
                                operationErrorMessage = nil
                                programIDs = updated.bundleIDs
                            }
                        } catch {
                            await MainActor.run {
                                operationErrorMessage = error.localizedDescription
                            }
                        }
                    }
                } label: {
                    Label(t("programs.add_apple_music"), systemImage: "music.note")
                }
                .buttonStyle(.bordered)
                .disabled(programIDs.contains("com.apple.Music"))
                .help(t("programs.add_apple_music_help"))
                .accessibilityIdentifier("programs.addAppleMusic")
            }

            Group {
                if isLoadingPrograms {
                    ProgressView(t("common.loading"))
                } else if programIDs.isEmpty {
                    ContentUnavailableView(t("programs.empty_title"), systemImage: "list.bullet", description: Text(t("programs.empty_description")))
                } else {
                    List {
                        ForEach(programIDs, id: \.self) { id in
                            ProgramRow(
                                info: displayInfo(for: id),
                                onRemove: {
                                    pendingRemovalBundleID = id
                                },
                                onSettings: {
                                    selectedProgramIDForSettings = id
                                    showingProgramSettings = true
                                }
                            )
                            .accessibilityIdentifier("programs.row.\(id)")
                            .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.inset)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .confirmationDialog(
            t("programs.confirm_remove.title"),
            isPresented: Binding(
                get: { pendingRemovalBundleID != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingRemovalBundleID = nil
                    }
                }
            ),
            presenting: pendingRemovalBundleID
        ) { bundleID in
            Button(t("common.delete"), role: .destructive) {
                removeProgram(bundleID)
            }
            Button(t("common.cancel"), role: .cancel) {
                pendingRemovalBundleID = nil
            }
        } message: { bundleID in
            Text(bundleID)
        }
        .onAppear {
            refreshMetadataCache()
            Task { await refreshProgramSettingsCache() }
        }
        .onChange(of: programIDs) { _, _ in
            refreshMetadataCache()
            Task { await refreshProgramSettingsCache() }
        }
        .sheet(isPresented: $showingProgramSettings) {
            ProgramsSettingsSheet(
                programDisplayName: selectedProgramIDForSettings.flatMap { displayInfo(for: $0).displayName } ?? t("programs.default_program_name"),
                programBundleID: selectedProgramIDForSettings,
                initialSettings: selectedProgramIDForSettings.flatMap { programSettingsCache[$0] } ?? ProgramPresenceSettings(),
                onSave: { updatedSettings in
                    guard let bundleID = selectedProgramIDForSettings else { return }
                    let saved = try await ConfigUtility.shared.setProgramSettings(updatedSettings, for: bundleID)
                    await MainActor.run {
                        programSettingsCache[bundleID] = saved
                    }
                }
            )
        }
    }

    /// Returns cached display metadata for a bundle identifier, falling back to a lightweight placeholder.
    private func displayInfo(for bundleID: String) -> ProgramDisplayInfo {
        #if os(macOS)
        return appMetadataCache[bundleID] ?? .fallback(bundleID: bundleID)
        #else
        return .fallback(bundleID: bundleID)
        #endif
    }

    /// Rebuilds the resolved application metadata cache for the current tracked bundle identifiers.
    private func refreshMetadataCache() {
        #if os(macOS)
        var nextCache: [String: ProgramDisplayInfo] = [:]
        for bundleID in programIDs {
            nextCache[bundleID] = ProgramDisplayInfo.resolve(bundleID: bundleID)
        }
        appMetadataCache = nextCache
        #endif
    }

    /// Loads persisted per-program presence settings into local view state.
    private func refreshProgramSettingsCache() async {
        let settings = await ConfigUtility.shared.allProgramSettings()
        await MainActor.run {
            programSettingsCache = settings
        }
    }

    private func removeProgram(_ bundleID: String) {
        Task {
            do {
                let updated = try await ConfigUtility.shared.removeBundleID(bundleID)
                await MainActor.run {
                    operationErrorMessage = nil
                    pendingRemovalBundleID = nil
                    programIDs = updated.bundleIDs
                }
            } catch {
                await MainActor.run {
                    pendingRemovalBundleID = nil
                    operationErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

/// Card-style row that shows app metadata and exposes settings and removal actions.
private struct ProgramRow: View {
    let info: ProgramDisplayInfo
    let onRemove: () -> Void
    let onSettings: () -> Void
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        HStack(spacing: 14) {
            programIcon

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(info.displayName)
                        .font(.headline)
                    if info.isResolved {
                        Text(t("programs.resolved"))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12), in: Capsule())
                            .foregroundStyle(.green)
                    } else {
                        Text(t("programs.no_metadata"))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.12), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }

                Text(info.bundleID)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)

                if let appPath = info.appPath {
                    Text(appPath)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text(t("programs.app_path_missing"))
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 20)

            HStack(spacing: 8) {
                Button(t("common.settings"), action: onSettings)
                    .buttonStyle(.bordered)
                Button(t("common.delete"), role: .destructive, action: onRemove)
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    @ViewBuilder
    private var programIcon: some View {
        #if os(macOS)
        if let icon = info.icon {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            fallbackIcon
        }
        #else
        fallbackIcon
        #endif
    }

    private var fallbackIcon: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.secondary.opacity(0.12))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "app.badge")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            )
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

/// Resolved display metadata for a tracked application, including icon and file-system location when available.
private struct ProgramDisplayInfo {
    let bundleID: String
    let displayName: String
    let appPath: String?
    #if os(macOS)
    let icon: NSImage?
    #endif
    let isResolved: Bool

    #if os(macOS)
    static func fallback(bundleID: String) -> ProgramDisplayInfo {
        ProgramDisplayInfo(
            bundleID: bundleID,
            displayName: bundleID.components(separatedBy: ".").last ?? bundleID,
            appPath: nil,
            icon: nil,
            isResolved: false
        )
    }

    static func resolve(bundleID: String) -> ProgramDisplayInfo {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return fallback(bundleID: bundleID)
        }

        let bundle = Bundle(url: appURL)
        let displayName =
            (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
            ?? appURL.deletingPathExtension().lastPathComponent

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 64, height: 64)

        return ProgramDisplayInfo(
            bundleID: bundleID,
            displayName: displayName,
            appPath: appURL.path,
            icon: icon,
            isResolved: true
        )
    }
    #else
    static func fallback(bundleID: String) -> ProgramDisplayInfo {
        ProgramDisplayInfo(
            bundleID: bundleID,
            displayName: bundleID.components(separatedBy: ".").last ?? bundleID,
            appPath: nil,
            isResolved: false
        )
    }
    #endif
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

/// Sheet for editing Discord activity templates and asset settings for a single tracked application.
private struct ProgramsSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let programDisplayName: String
    let programBundleID: String?
    let initialSettings: ProgramPresenceSettings
    let onSave: (ProgramPresenceSettings) async throws -> Void
    @EnvironmentObject private var localizationManager: LocalizationManager

    @State private var draftSettings: ProgramPresenceSettings
    @State private var isSaving: Bool = false
    @State private var saveErrorMessage: String?
    init(
        programDisplayName: String,
        programBundleID: String?,
        initialSettings: ProgramPresenceSettings,
        onSave: @escaping (ProgramPresenceSettings) async throws -> Void
    ) {
        self.programDisplayName = programDisplayName
        self.programBundleID = programBundleID
        self.initialSettings = initialSettings
        self.onSave = onSave
        _draftSettings = State(initialValue: initialSettings)
    }

    private var hasChanges: Bool {
        draftSettings != initialSettings
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button(t("common.cancel")) { dismiss() }
                        .disabled(isSaving)
                    Spacer()
                    Button(t("common.save")) {
                        save()
                    }
                    .disabled(!hasChanges || isSaving)
                    .keyboardShortcut(.defaultAction)

                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(programDisplayName)
                        .font(.title3.weight(.semibold))
                    if let programBundleID {
                        Text(programBundleID)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Text(t("programs.sheet.save_notice"))
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                    Text(t("programs.sheet.supported_templates"))
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                if let saveErrorMessage {
                    Label(saveErrorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("programs.settings.saveError")
                }

                Divider()
                Form {
                    Section {
                        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 10) {
                            GridRow(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(t("programs.sheet.activity_type")).font(.headline)
                                    Picker(t("programs.sheet.activity_type"), selection: $draftSettings.activityType) {
                                        ForEach(ProgramPresenceSettings.ActivityType.allCases) { t in
                                            Text(t.localizedLabel).tag(t)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            GridRow(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(t("programs.sheet.details")).font(.headline)
                                    TextField(t("programs.sheet.details_placeholder"), text: $draftSettings.detailText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            GridRow(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(t("programs.sheet.state_message")).font(.headline)
                                    TextField(t("programs.sheet.state_placeholder"), text: $draftSettings.stateText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    Divider()
                    Section {
                        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 10) {
                            GridRow { Toggle(t("programs.sheet.use_app_icon_large_image"), isOn: $draftSettings.useAppIconForLargeImage) }
                            GridRow {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(t("programs.sheet.large_image_key")).font(.headline)
                                    TextField(t("programs.sheet.discord_asset_key_placeholder"), text: $draftSettings.largeImageKey)
                                }
                            }
                            GridRow {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(t("programs.sheet.large_image_text")).font(.headline)
                                    TextField(t("programs.sheet.large_image_text_placeholder"), text: $draftSettings.largeImageText)
                                }
                            }
                            GridRow {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(t("programs.sheet.small_image_key")).font(.headline)
                                    TextField(t("programs.sheet.discord_asset_key_placeholder"), text: $draftSettings.smallImageKey)
                                }
                            }
                            GridRow {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(t("programs.sheet.small_image_text")).font(.headline)
                                    TextField(t("programs.sheet.small_image_text_placeholder"), text: $draftSettings.smallImageText)
                                }
                            }
                        }
                    }
                    Divider()
                    Section {
                        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 10) {
                            GridRow {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(t("programs.sheet.party_current")).font(.headline)
                                    HStack {
                                        Stepper(value: $draftSettings.partyCurrent, in: 0...max(0, draftSettings.partyMax)) { EmptyView() }
                                        Text("\(draftSettings.partyCurrent)").foregroundStyle(.secondary)
                                    }
                                }
                            }
                            GridRow {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(t("programs.sheet.party_max")).font(.headline)
                                    HStack {
                                        Stepper(value: $draftSettings.partyMax, in: max(1, draftSettings.partyCurrent)...99) { EmptyView() }
                                        Text("\(draftSettings.partyMax)").foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(minWidth: 720, idealWidth: 820)
            .frame(maxHeight: 720)
        }
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }

    private func save() {
        guard !isSaving else { return }

        isSaving = true
        saveErrorMessage = nil

        Task {
            do {
                try await onSave(draftSettings)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveErrorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct ProgramsViewPreviewContainer: View {
    @State private var programIDs: [String] = ["com.apple.Music"]
    @State private var isLoadingPrograms = false
    @State private var showing = false
    @State private var selectedProgramID: String? = nil

    var body: some View {
        ProgramsView(
            programIDs: $programIDs,
            isLoadingPrograms: $isLoadingPrograms,
            showingProgramSettings: $showing,
            selectedProgramIDForSettings: $selectedProgramID
        )
    }
}

#Preview {
    ProgramsViewPreviewContainer()
}
