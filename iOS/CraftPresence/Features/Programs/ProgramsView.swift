import Combine
import SwiftUI

/// Manual Rich Presence preset manager. Users choose exactly what Discord should display.
struct ProgramsView: View {
    @Binding var programIDs: [String]
    @Binding var isLoadingPrograms: Bool
    @Binding var showingProgramSettings: Bool
    @Binding var selectedProgramIDForSettings: String?

    @ObservedObject private var discordManager = DiscordSDKManager.shared
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var presets: [CustomPresencePreset] = []
    @State private var activePresetID: UUID?
    @State private var editingPreset: CustomPresencePreset?
    @State private var isPresentingEditor = false
    @State private var statusMessage = ""

    var body: some View {
        CPSettingsPage {
            CPHeaderCard(
                title: t("presets.title"),
                subtitle: t("presets.subtitle"),
                systemImage: "slider.horizontal.3",
                tint: .orange
            )

            controlPanel

            if !statusMessage.isEmpty {
                messagePanel(statusMessage)
            }

            presetList
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
            if showsInlinePageHeader {
                Label(t("presets.title"), systemImage: "slider.horizontal.3")
                    .font(.title2.weight(.bold))
                    .accessibilityIdentifier("programs.title")
            }
            if showsInlinePageHeader {
                Text(t("presets.subtitle"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(t("presets.subtitle"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("programs.title")
            }
        }
    }

    private var showsInlinePageHeader: Bool {
        horizontalSizeClass != .compact
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

            LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
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
        .background(CPStyle.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var actionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 148), spacing: 10)]
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
        CPStyle.cardBackground
    }

    private func messagePanel(_ message: String) -> some View {
        Label(message, systemImage: "info.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            var publishedPreset = preset.normalized
            let startDate = publishedPreset.elapsedStartDateForPublish()
            publishedPreset.elapsedStartDate = startDate
            if discordManager.authorizationStatus != .authorized {
                _ = try await DiscordSDKManager.shared.authorizeIfNeeded()
            }
            try await DiscordSDKManager.shared.updateActivity(
                name: publishedPreset.title.nilIfEmpty ?? "CraftPresence",
                state: publishedPreset.state.nilIfEmpty,
                details: publishedPreset.details.nilIfEmpty,
                largeImageKey: publishedPreset.largeImageKey.nilIfEmpty,
                largeImageText: publishedPreset.largeImageText.nilIfEmpty,
                smallImageKey: publishedPreset.smallImageKey.nilIfEmpty,
                smallImageText: publishedPreset.smallImageText.nilIfEmpty,
                partyID: partyID(for: publishedPreset),
                partyCurrent: partyCurrent(for: publishedPreset),
                partyMax: partyMax(for: publishedPreset),
                start: startDate,
                activityType: publishedPreset.activityType.discordActivityType
            )
            _ = try await ConfigUtility.shared.setLastCustomPresence(publishedPreset)
            _ = try await ConfigUtility.shared.setAppliedCustomPresence(publishedPreset)
            _ = try await ConfigUtility.shared.setCustomPresenceDraft(publishedPreset)
            _ = try await ConfigUtility.shared.setActiveCustomPresencePreset(id: publishedPreset.id)
            await reloadPresets()
            statusMessage = String(format: t("presets.published_format"), publishedPreset.title)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func clearPresence() async {
        do {
            try await DiscordSDKManager.shared.clearActivity()
            _ = try await ConfigUtility.shared.setActiveCustomPresencePreset(id: nil)
            _ = try await ConfigUtility.shared.setLastCustomPresence(nil)
            _ = try await ConfigUtility.shared.setAppliedCustomPresence(nil)
            await reloadPresets()
            statusMessage = t("presets.cleared")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func partyID(for preset: CustomPresencePreset) -> String? {
        preset.partyID
    }

    private func partyCurrent(for preset: CustomPresencePreset) -> Int? {
        preset.partyCurrentValue
    }

    private func partyMax(for preset: CustomPresencePreset) -> Int? {
        preset.partyMaxValue
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
        .background(CPStyle.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                PresencePresetForm(preset: $preset)
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
        preset.normalized
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

private struct PresencePresetForm: View {
    @Binding var preset: CustomPresencePreset
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        Section(t("presets.editor.identity")) {
            TextField(t("presets.editor.title"), text: $preset.title)
                .accessibilityIdentifier("presenceForm.title")
            Picker(t("programs.sheet.activity_type"), selection: $preset.activityType) {
                ForEach(ProgramPresenceSettings.ActivityType.allCases) { type in
                    Label(type.localizedLabel, systemImage: type.systemImage).tag(type)
                }
            }
            .accessibilityIdentifier("presenceForm.activityType")
        }

        Section(t("presets.editor.text")) {
            TextField(t("programs.sheet.details"), text: $preset.details, axis: .vertical)
                .accessibilityIdentifier("presenceForm.details")
            TextField(t("programs.sheet.state_message"), text: $preset.state, axis: .vertical)
                .accessibilityIdentifier("presenceForm.state")
            Toggle(t("presets.editor.elapsed_time"), isOn: $preset.usesElapsedTime)
                .accessibilityIdentifier("presenceForm.elapsedTime")
        }

        Section {
            TextField(t("programs.sheet.large_image_key"), text: $preset.largeImageKey)
                .accessibilityIdentifier("presenceForm.largeImageKey")
            TextField(t("programs.sheet.large_image_text"), text: $preset.largeImageText)
                .accessibilityIdentifier("presenceForm.largeImageText")
            TextField(t("programs.sheet.small_image_key"), text: $preset.smallImageKey)
                .accessibilityIdentifier("presenceForm.smallImageKey")
            TextField(t("programs.sheet.small_image_text"), text: $preset.smallImageText)
                .accessibilityIdentifier("presenceForm.smallImageText")
        } header: {
            Text(t("presets.editor.assets"))
        } footer: {
            Text(t("presets.editor.assets_help"))
        }

        Section(t("presets.editor.party")) {
            Toggle(t("presets.editor.party_enabled"), isOn: $preset.usesParty)
                .accessibilityIdentifier("presenceForm.partyEnabled")
            Stepper(value: $preset.partyCurrent, in: 0...max(0, preset.partyMax)) {
                LabeledContent(t("programs.sheet.party_current"), value: "\(preset.partyCurrent)")
            }
            .disabled(!preset.usesParty)
            .accessibilityIdentifier("presenceForm.partyCurrent")
            Stepper(value: $preset.partyMax, in: max(1, preset.partyCurrent)...99) {
                LabeledContent(t("programs.sheet.party_max"), value: "\(preset.partyMax)")
            }
            .disabled(!preset.usesParty)
            .accessibilityIdentifier("presenceForm.partyMax")
        }
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

struct CustomPresenceView: View {
    @ObservedObject private var discordManager = DiscordSDKManager.shared
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    @State private var draft = CustomPresencePreset.makeDraft()
    @State private var statusMessage = ""
    @State private var hasLoadedInitialDraft = false
    @State private var previewNow = Date()

    var body: some View {
        CPSettingsPage {
            CPHeaderCard(
                title: t("custom_presence.title"),
                subtitle: t("custom_presence.subtitle"),
                systemImage: "slider.horizontal.3",
                tint: .blue
            )

            previewPanel
            actionPanel

            if !statusMessage.isEmpty {
                messagePanel(statusMessage)
            }

            editorPanel
        }
        .task {
            await loadCurrentPresenceDraft()
        }
        .onChange(of: draft) { _, newDraft in
            guard hasLoadedInitialDraft else { return }
            Task {
                await persistDraft(newDraft)
            }
        }
        .onDisappear {
            let currentDraft = draft
            Task {
                await persistDraft(currentDraft)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else { return }
            let currentDraft = draft
            Task {
                await persistDraft(currentDraft)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            previewNow = date
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsInlinePageHeader {
                Label(t("custom_presence.title"), systemImage: "slider.horizontal.3")
                    .font(.title2.weight(.bold))
                    .accessibilityIdentifier("customPresence.title")
            }
            if showsInlinePageHeader {
                Text(t("custom_presence.subtitle"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(t("custom_presence.subtitle"))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("customPresence.title")
            }
        }
    }

    private var showsInlinePageHeader: Bool {
        horizontalSizeClass != .compact
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(previewActivityHeaderText)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "ellipsis")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary)

                    Image(systemName: previewAssetSymbol)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(CPStyle.cardBackground)
                        .imageScale(.large)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(previewDetailsText)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)

                    Text(previewStateText)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    if draft.normalized.usesElapsedTime {
                        HStack(spacing: 4) {
                            Image(systemName: "desktopcomputer")
                                .font(.caption2.weight(.bold))
                            Text(previewElapsedText)
                                .font(.caption.monospacedDigit().weight(.semibold))
                        }
                        .foregroundStyle(.green)
                        .lineLimit(1)
                        .padding(.top, 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(CPStyle.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var previewActivityHeaderText: String {
        "\(draft.normalized.activityType.rawValue) \(previewTitleText)"
    }

    private var previewTitleText: String {
        draft.normalized.title.nilIfEmpty ?? t("presets.new_default_title")
    }

    private var previewDetailsText: String {
        draft.normalized.details.nilIfEmpty ?? previewTitleText
    }

    private var previewStateText: String {
        draft.normalized.state.nilIfEmpty ?? t("presets.no_state")
    }

    private var previewAssetSymbol: String {
        draft.normalized.largeImageKey.nilIfEmpty == nil ? "questionmark" : draft.activityType.systemImage
    }

    private var previewElapsedText: String {
        let startDate = draft.normalized.elapsedStartDate ?? previewNow
        let elapsed = max(1, previewNow.timeIntervalSince(startDate))
        return Self.previewElapsedFormatter.string(from: elapsed) ?? "00:00:01"
    }

    private static let previewElapsedFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    private var actionPanel: some View {
        LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
            Button {
                Task { await publishDraft() }
            } label: {
                Label(t("custom_presence.publish_now"), systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(draft.normalized.title.isEmpty)
            .accessibilityIdentifier("customPresence.publish")

            Button {
                Task { await saveDraftAsPreset() }
            } label: {
                Label(t("custom_presence.save_as_preset"), systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(draft.normalized.title.isEmpty)
            .accessibilityIdentifier("customPresence.saveAsPreset")

            Button {
                Task { await clearPresence() }
            } label: {
                Label(t("presets.clear_presence"), systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .tint(.red)
            .accessibilityIdentifier("customPresence.clear")

            Button {
                draft = CustomPresencePreset.makeDraft()
                statusMessage = t("custom_presence.reset")
            } label: {
                Label(t("custom_presence.reset_button"), systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .accessibilityIdentifier("customPresence.reset")
        }
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 152), spacing: 10)]
    }

    private var editorPanel: some View {
        PresencePresetInlineForm(preset: $draft)
            .accessibilityIdentifier("customPresence.editor")
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

    private func messagePanel(_ message: String) -> some View {
        Label(message, systemImage: "info.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(CPStyle.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @MainActor
    private func publishDraft() async {
        do {
            var preset = draft.normalized
            let startDate = preset.elapsedStartDateForPublish()
            preset.elapsedStartDate = startDate
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
                partyID: preset.partyID,
                partyCurrent: preset.partyCurrentValue,
                partyMax: preset.partyMaxValue,
                start: startDate,
                activityType: preset.activityType.discordActivityType
            )
            _ = try await ConfigUtility.shared.setLastCustomPresence(preset)
            _ = try await ConfigUtility.shared.setAppliedCustomPresence(preset)
            _ = try await ConfigUtility.shared.setCustomPresenceDraft(preset)
            _ = try await ConfigUtility.shared.setActiveCustomPresencePreset(id: nil)
            draft = preset
            hasLoadedInitialDraft = true
            statusMessage = String(format: t("custom_presence.published_format"), preset.title)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveDraftAsPreset() async {
        do {
            let preset = draft.normalized
            _ = try await ConfigUtility.shared.upsertCustomPresencePreset(preset)
            _ = try await ConfigUtility.shared.setLastCustomPresence(preset)
            _ = try await ConfigUtility.shared.setCustomPresenceDraft(preset)
            draft = preset
            hasLoadedInitialDraft = true
            statusMessage = t("presets.saved")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func clearPresence() async {
        do {
            try await DiscordSDKManager.shared.clearActivity()
            _ = try await ConfigUtility.shared.setActiveCustomPresencePreset(id: nil)
            _ = try await ConfigUtility.shared.setLastCustomPresence(nil)
            _ = try await ConfigUtility.shared.setAppliedCustomPresence(nil)
            statusMessage = t("presets.cleared")
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadCurrentPresenceDraft() async {
        let appliedPresence = await ConfigUtility.shared.currentAppliedCustomPresence()
        if let liveActivity = try? await DiscordSDKManager.shared.currentPresenceActivity(),
           let liveDraft = CustomPresencePreset(discordActivity: liveActivity) {
            draft = liveDraft.preservingElapsedTime(from: appliedPresence)
            hasLoadedInitialDraft = true
            return
        }

        if let storedDraft = await ConfigUtility.shared.currentCustomPresenceDraft() {
            draft = storedDraft
        }
        hasLoadedInitialDraft = true
    }

    private func persistDraft(_ draft: CustomPresencePreset) async {
        do {
            _ = try await ConfigUtility.shared.setCustomPresenceDraft(draft.normalized)
        } catch {
            #if DEBUG
            print("Failed to persist custom Presence draft: \(error)")
            #endif
        }
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

private struct PresencePresetInlineForm: View {
    @Binding var preset: CustomPresencePreset
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            formSection(title: t("presets.editor.identity")) {
                TextField(t("presets.editor.title"), text: $preset.title)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("presenceForm.title")

                Picker(t("programs.sheet.activity_type"), selection: $preset.activityType) {
                    ForEach(ProgramPresenceSettings.ActivityType.allCases) { type in
                        Label(type.localizedLabel, systemImage: type.systemImage).tag(type)
                    }
                }
                .accessibilityIdentifier("presenceForm.activityType")
            }

            formSection(title: t("presets.editor.text")) {
                TextField(t("programs.sheet.details"), text: $preset.details, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("presenceForm.details")

                TextField(t("programs.sheet.state_message"), text: $preset.state, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("presenceForm.state")

                Toggle(t("presets.editor.elapsed_time"), isOn: $preset.usesElapsedTime)
                    .accessibilityIdentifier("presenceForm.elapsedTime")
            }

            formSection(
                title: t("presets.editor.assets"),
                footer: t("presets.editor.assets_help")
            ) {
                TextField(t("programs.sheet.large_image_key"), text: $preset.largeImageKey)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("presenceForm.largeImageKey")

                TextField(t("programs.sheet.large_image_text"), text: $preset.largeImageText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("presenceForm.largeImageText")

                TextField(t("programs.sheet.small_image_key"), text: $preset.smallImageKey)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("presenceForm.smallImageKey")

                TextField(t("programs.sheet.small_image_text"), text: $preset.smallImageText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("presenceForm.smallImageText")
            }

            formSection(title: t("presets.editor.party")) {
                Toggle(t("presets.editor.party_enabled"), isOn: $preset.usesParty)
                    .accessibilityIdentifier("presenceForm.partyEnabled")

                Stepper(value: $preset.partyCurrent, in: 0...max(0, preset.partyMax)) {
                    LabeledContent(t("programs.sheet.party_current"), value: "\(preset.partyCurrent)")
                }
                .disabled(!preset.usesParty)
                .accessibilityIdentifier("presenceForm.partyCurrent")

                Stepper(value: $preset.partyMax, in: max(1, preset.partyCurrent)...99) {
                    LabeledContent(t("programs.sheet.party_max"), value: "\(preset.partyMax)")
                }
                .disabled(!preset.usesParty)
                .accessibilityIdentifier("presenceForm.partyMax")
            }
        }
    }

    private func formSection<Content: View>(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            content()

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(CPStyle.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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

extension CustomPresencePreset {
    static func makeDraft() -> CustomPresencePreset {
        CustomPresencePreset(
            title: LocalizationManager.shared.string("custom_presence.default_title"),
            activityType: .playing,
            details: "",
            state: ""
        )
    }

    init?(discordActivity: DiscordActivity) {
        guard let title = discordActivity.name?.nilIfEmpty else { return nil }
        let partyCurrent = discordActivity.party.currentSize ?? 1
        let partyMax = max(discordActivity.party.maxSize ?? partyCurrent, partyCurrent)

        self.init(
            title: title,
            activityType: ProgramPresenceSettings.ActivityType(discordActivityType: discordActivity.type),
            details: discordActivity.details ?? "",
            state: discordActivity.state ?? "",
            largeImageKey: discordActivity.assets.largeImage ?? "",
            largeImageText: discordActivity.assets.largeText ?? "",
            smallImageKey: discordActivity.assets.smallImage ?? "",
            smallImageText: discordActivity.assets.smallText ?? "",
            usesElapsedTime: discordActivity.timestamps.start != nil,
            elapsedStartDate: discordActivity.timestamps.start,
            usesParty: discordActivity.party.currentSize != nil && discordActivity.party.maxSize != nil,
            partyCurrent: partyCurrent,
            partyMax: partyMax
        )
    }

    var normalized: CustomPresencePreset {
        var copy = self
        copy.title = copy.title.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.details = copy.details.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.state = copy.state.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.largeImageKey = copy.largeImageKey.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.largeImageText = copy.largeImageText.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.smallImageKey = copy.smallImageKey.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.smallImageText = copy.smallImageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !copy.usesElapsedTime {
            copy.elapsedStartDate = nil
        }
        return copy
    }

    func elapsedStartDateForPublish(now: Date = Date()) -> Date? {
        guard usesElapsedTime else { return nil }
        return elapsedStartDate ?? now
    }

    func preservingElapsedTime(from fallback: CustomPresencePreset?) -> CustomPresencePreset {
        guard let fallback,
              fallback.usesElapsedTime,
              let fallbackStartDate = fallback.elapsedStartDate,
              elapsedStartDate == nil,
              matchesPresencePayload(of: fallback) else {
            return self
        }

        var copy = self
        copy.usesElapsedTime = true
        copy.elapsedStartDate = fallbackStartDate
        return copy
    }

    var partyID: String? {
        guard usesParty, partyCurrent > 0, partyMax >= partyCurrent else { return nil }
        return "preset:\(id.uuidString)"
    }

    var partyCurrentValue: Int? {
        partyID == nil ? nil : partyCurrent
    }

    var partyMaxValue: Int? {
        partyID == nil ? nil : partyMax
    }

    private func matchesPresencePayload(of other: CustomPresencePreset) -> Bool {
        normalizedString(title) == normalizedString(other.title)
            && activityType == other.activityType
            && normalizedString(details) == normalizedString(other.details)
            && normalizedString(state) == normalizedString(other.state)
            && normalizedString(largeImageKey) == normalizedString(other.largeImageKey)
            && normalizedString(largeImageText) == normalizedString(other.largeImageText)
            && normalizedString(smallImageKey) == normalizedString(other.smallImageKey)
            && normalizedString(smallImageText) == normalizedString(other.smallImageText)
            && partyCurrentValue == other.partyCurrentValue
            && partyMaxValue == other.partyMaxValue
    }

    private func normalizedString(_ value: String) -> String? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

private extension ProgramPresenceSettings.ActivityType {
    init(discordActivityType: DiscordActivity.ActivityType) {
        switch discordActivityType {
        case .playing:
            self = .playing
        case .streaming:
            self = .streaming
        case .listening:
            self = .listening
        case .watching:
            self = .watching
        case .competing:
            self = .competing
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
