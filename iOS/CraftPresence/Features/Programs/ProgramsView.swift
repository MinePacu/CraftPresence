import SwiftUI

/// Manual Rich Presence preset manager. Users choose exactly what Discord should display.
struct ProgramsView: View {
    @Binding var programIDs: [String]
    @Binding var isLoadingPrograms: Bool
    @Binding var showingProgramSettings: Bool
    @Binding var selectedProgramIDForSettings: String?

    @ObservedObject private var discordManager = DiscordSDKManager.shared
    @EnvironmentObject private var localizationManager: LocalizationManager

    @State private var presets: [CustomPresencePreset] = []
    @State private var activePresetID: UUID?
    @State private var editingPreset: CustomPresencePreset?
    @State private var isPresentingEditor = false
    @State private var statusMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                controlPanel
                if !statusMessage.isEmpty {
                    messagePanel(statusMessage)
                }
                presetList
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .task {
            await reloadPresets()
            isLoadingPrograms = false
        }
        .sheet(isPresented: $isPresentingEditor) {
            PresencePresetEditor(
                initialPreset: editingPreset ?? CustomPresencePreset(
                    title: t("presets.new_default_title"),
                    activityType: .playing,
                    details: "",
                    state: ""
                ),
                onSave: { preset in
                    Task {
                        await savePreset(preset)
                    }
                }
            )
            .environmentObject(localizationManager)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(t("presets.title"), systemImage: "slider.horizontal.3")
                .font(.title2.weight(.bold))
                .accessibilityIdentifier("programs.title")
            Text(t("presets.subtitle"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("presets.manual_control"))
                        .font(.headline)
                    Text(t("presets.manual_control_description"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Text(t(discordManager.dashboardStatus.localizationKey))
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(statusColor)
            }

            HStack(spacing: 10) {
                Button {
                    editingPreset = nil
                    isPresentingEditor = true
                } label: {
                    Label(t("presets.create"), systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("programs.add")

                Button {
                    Task { await clearPresence() }
                } label: {
                    Label(t("presets.clear_presence"), systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .disabled(activePresetID == nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    private var presetList: some View {
        Group {
            if presets.isEmpty {
                ContentUnavailableView(
                    t("presets.empty_title"),
                    systemImage: "slider.horizontal.3",
                    description: Text(t("presets.empty_description"))
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(presets) { preset in
                        PresencePresetRow(
                            preset: preset,
                            isActive: preset.id == activePresetID,
                            onPublish: { Task { await publish(preset) } },
                            onEdit: {
                                editingPreset = preset
                                isPresentingEditor = true
                            },
                            onDelete: { Task { await deletePreset(preset) } }
                        )
                        .accessibilityIdentifier("programs.row.\(preset.id.uuidString)")
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        switch discordManager.dashboardStatus {
        case .ready:
            return .green
        case .configured, .authorizing, .connecting:
            return .orange
        case .failed, .unauthorized:
            return .red
        case .notConfigured:
            return .secondary
        }
    }

    private var cardBackground: some ShapeStyle {
        Color.secondary.opacity(0.08)
    }

    private func messagePanel(_ message: String) -> some View {
        Label(message, systemImage: "info.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @MainActor
    private func reloadPresets() async {
        let settings = await ConfigUtility.shared.currentSettings()
        presets = settings.customPresencePresets
        activePresetID = settings.activeCustomPresencePresetID
        programIDs = settings.bundleIDs
    }

    @MainActor
    private func savePreset(_ preset: CustomPresencePreset) async {
        do {
            _ = try await ConfigUtility.shared.upsertCustomPresencePreset(preset)
            await reloadPresets()
            statusMessage = t("presets.saved")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deletePreset(_ preset: CustomPresencePreset) async {
        do {
            _ = try await ConfigUtility.shared.removeCustomPresencePreset(id: preset.id)
            await reloadPresets()
            statusMessage = t("presets.deleted")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func publish(_ preset: CustomPresencePreset) async {
        do {
            if discordManager.authorizationStatus != .authorized {
                _ = try await DiscordSDKManager.shared.authorizeIfNeeded()
            }
            try await DiscordSDKManager.shared.updateActivity(
                name: preset.title.nilIfEmpty ?? "CraftPresence",
                state: preset.state.nilIfEmpty,
                details: preset.details.nilIfEmpty,
                largeImageKey: preset.largeImageKey.nilIfEmpty,
                largeImageText: preset.largeImageText.nilIfEmpty,
                smallImageKey: preset.smallImageKey.nilIfEmpty,
                smallImageText: preset.smallImageText.nilIfEmpty,
                partyID: partyID(for: preset),
                partyCurrent: partyCurrent(for: preset),
                partyMax: partyMax(for: preset),
                start: preset.usesElapsedTime ? Date() : nil,
                activityType: preset.activityType.discordActivityType
            )
            _ = try await ConfigUtility.shared.setActiveCustomPresencePreset(id: preset.id)
            await reloadPresets()
            statusMessage = String(format: t("presets.published_format"), preset.title)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func clearPresence() async {
        do {
            try await DiscordSDKManager.shared.clearActivity()
            _ = try await ConfigUtility.shared.setActiveCustomPresencePreset(id: nil)
            await reloadPresets()
            statusMessage = t("presets.cleared")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func partyID(for preset: CustomPresencePreset) -> String? {
        guard preset.partyCurrent > 0, preset.partyMax >= preset.partyCurrent else { return nil }
        return "preset:\(preset.id.uuidString)"
    }

    private func partyCurrent(for preset: CustomPresencePreset) -> Int? {
        partyID(for: preset) == nil ? nil : preset.partyCurrent
    }

    private func partyMax(for preset: CustomPresencePreset) -> Int? {
        partyID(for: preset) == nil ? nil : preset.partyMax
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

private struct PresencePresetRow: View {
    let preset: CustomPresencePreset
    let isActive: Bool
    let onPublish: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            icon

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(preset.title)
                        .font(.headline)
                    if isActive {
                        Text(t("presets.active"))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }

                Text(preset.details.nilIfEmpty ?? t("presets.no_details"))
                    .font(.subheadline)
                Text(preset.state.nilIfEmpty ?? t("presets.no_state"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button {
                    onPublish()
                } label: {
                    Label(t("presets.publish"), systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onEdit()
                } label: {
                    Label(t("common.settings"), systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(t("common.delete"), systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .labelStyle(.iconOnly)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var icon: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isActive ? Color.green.opacity(0.14) : Color.accentColor.opacity(0.12))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: preset.activityType.systemImage)
                    .imageScale(.large)
                    .foregroundStyle(isActive ? .green : .accentColor)
            )
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

private struct PresencePresetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localizationManager: LocalizationManager

    let onSave: (CustomPresencePreset) -> Void
    @State private var preset: CustomPresencePreset

    init(initialPreset: CustomPresencePreset, onSave: @escaping (CustomPresencePreset) -> Void) {
        self.onSave = onSave
        _preset = State(initialValue: initialPreset)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(t("presets.editor.identity")) {
                    TextField(t("presets.editor.title"), text: $preset.title)
                    Picker(t("programs.sheet.activity_type"), selection: $preset.activityType) {
                        ForEach(ProgramPresenceSettings.ActivityType.allCases) { type in
                            Label(type.localizedLabel, systemImage: type.systemImage).tag(type)
                        }
                    }
                }

                Section(t("presets.editor.text")) {
                    TextField(t("programs.sheet.details"), text: $preset.details, axis: .vertical)
                    TextField(t("programs.sheet.state_message"), text: $preset.state, axis: .vertical)
                    Toggle(t("presets.editor.elapsed_time"), isOn: $preset.usesElapsedTime)
                }

                Section(t("presets.editor.assets")) {
                    TextField(t("programs.sheet.large_image_key"), text: $preset.largeImageKey)
                    TextField(t("programs.sheet.large_image_text"), text: $preset.largeImageText)
                    TextField(t("programs.sheet.small_image_key"), text: $preset.smallImageKey)
                    TextField(t("programs.sheet.small_image_text"), text: $preset.smallImageText)
                }

                Section(t("presets.editor.party")) {
                    Stepper(value: $preset.partyCurrent, in: 0...max(0, preset.partyMax)) {
                        LabeledContent(t("programs.sheet.party_current"), value: "\(preset.partyCurrent)")
                    }
                    Stepper(value: $preset.partyMax, in: max(1, preset.partyCurrent)...99) {
                        LabeledContent(t("programs.sheet.party_max"), value: "\(preset.partyMax)")
                    }
                }
            }
            .navigationTitle(t("presets.editor.title_bar"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("common.save")) {
                        onSave(normalizedPreset)
                        dismiss()
                    }
                    .disabled(normalizedPreset.title.isEmpty)
                }
            }
        }
#if os(macOS) || targetEnvironment(macCatalyst)
        .frame(minWidth: 520, minHeight: 560)
#endif
    }

    private var normalizedPreset: CustomPresencePreset {
        var copy = preset
        copy.title = copy.title.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.details = copy.details.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.state = copy.state.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.largeImageKey = copy.largeImageKey.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.largeImageText = copy.largeImageText.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.smallImageKey = copy.smallImageKey.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.smallImageText = copy.smallImageText.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

extension ProgramPresenceSettings.ActivityType {
    var systemImage: String {
        switch self {
        case .playing:
            return "gamecontroller.fill"
        case .streaming:
            return "dot.radiowaves.left.and.right"
        case .listening:
            return "music.note"
        case .watching:
            return "play.tv"
        case .competing:
            return "flag.checkered"
        }
    }

    var discordActivityType: DiscordActivity.ActivityType {
        switch self {
        case .playing:
            return .playing
        case .streaming:
            return .streaming
        case .listening:
            return .listening
        case .watching:
            return .watching
        case .competing:
            return .competing
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
