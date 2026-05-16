import SwiftUI

/// macOS management surface for saved Discord Rich Presence presets.
struct PresencePresetsView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var presets: [PresencePreset] = []
    @State private var activePresetID: UUID?
    @State private var isLoading = true
    @State private var isPublishingID: UUID?
    @State private var operationMessage: String?
    @State private var operationErrorMessage: String?
    @State private var editingPreset: PresencePreset?
    @State private var pendingDeletePreset: PresencePreset?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let operationErrorMessage {
                Label(operationErrorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("presets.operationError")
            }

            if let operationMessage {
                Label(operationMessage, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("presets.operationMessage")
            }

            Group {
                if isLoading {
                    ProgressView(t("common.loading"))
                } else if presets.isEmpty {
                    ContentUnavailableView(
                        t("presets.empty_title"),
                        systemImage: "rectangle.stack.badge.plus",
                        description: Text(t("presets.empty_description"))
                    )
                } else {
                    List {
                        ForEach(presets) { preset in
                            PresencePresetCard(
                                preset: preset,
                                isActive: activePresetID == preset.id,
                                isPublishing: isPublishingID == preset.id,
                                onPublish: { publish(preset) },
                                onEdit: { editingPreset = preset },
                                onDuplicate: { duplicate(preset) },
                                onDelete: { pendingDeletePreset = preset }
                            )
                            .accessibilityIdentifier("presets.row.\(preset.id.uuidString)")
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
        .task { await reload() }
        .sheet(item: $editingPreset) { preset in
            PresencePresetEditorSheet(initialPreset: preset) { updatedPreset in
                let saved = try await ConfigUtility.shared.upsertPresencePreset(updatedPreset)
                await MainActor.run {
                    replacePreset(saved)
                    operationMessage = t("presets.message.saved")
                    operationErrorMessage = nil
                }
                await reload()
            }
            .environmentObject(localizationManager)
        }
        .confirmationDialog(
            t("presets.confirm_delete.title"),
            isPresented: Binding(
                get: { pendingDeletePreset != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeletePreset = nil
                    }
                }
            ),
            presenting: pendingDeletePreset
        ) { preset in
            Button(t("common.delete"), role: .destructive) {
                delete(preset)
            }
            Button(t("common.cancel"), role: .cancel) {
                pendingDeletePreset = nil
            }
        } message: { preset in
            Text(preset.title)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(t("presets.title"), systemImage: "rectangle.stack")
                        .font(.title2).bold()
                        .accessibilityIdentifier("presets.title")
                    Text(t("presets.subtitle"))
                        .foregroundStyle(.secondary)
                    Text(t("presets.description"))
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    restoreDefaults()
                } label: {
                    Label(t("presets.restore_defaults"), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("presets.restoreDefaults")
            }
        }
    }

    private func reload() async {
        let settings = await ConfigUtility.shared.currentSettings()
        await MainActor.run {
            presets = settings.presencePresets.sorted { lhs, rhs in
                if lhs.isDefault != rhs.isDefault {
                    return lhs.isDefault && !rhs.isDefault
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            activePresetID = settings.activePresencePresetID
            isLoading = false
        }
    }

    private func publish(_ preset: PresencePreset) {
        guard isPublishingID == nil else { return }
        isPublishingID = preset.id
        operationMessage = nil
        operationErrorMessage = nil

        Task {
            do {
                var publishedPreset = preset
                let publishTime = Date()
                publishedPreset.elapsedStartDate = publishedPreset.elapsedStartDateForPublish(now: publishTime)
                publishedPreset.pausedElapsedDuration = publishedPreset.pausedElapsedDurationForPublish(now: publishTime)
                let payload = AppliedPresencePayload(presencePreset: publishedPreset)
                try await DiscordSDKManager.shared.publishAppliedPresence(payload)
                _ = try await ConfigUtility.shared.upsertPresencePreset(publishedPreset)
                _ = try await ConfigUtility.shared.setActivePresencePreset(id: preset.id)
                await reload()
                await MainActor.run {
                    isPublishingID = nil
                    operationMessage = t("presets.message.published")
                }
            } catch {
                await MainActor.run {
                    isPublishingID = nil
                    operationErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func duplicate(_ preset: PresencePreset) {
        Task {
            do {
                _ = try await ConfigUtility.shared.duplicatePresencePreset(
                    id: preset.id,
                    title: t("presets.copy_title_format").replacingOccurrences(of: "%@", with: preset.title)
                )
                await reload()
                await MainActor.run {
                    operationMessage = t("presets.message.duplicated")
                    operationErrorMessage = nil
                }
            } catch {
                await MainActor.run {
                    operationErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func delete(_ preset: PresencePreset) {
        Task {
            do {
                _ = try await ConfigUtility.shared.removePresencePreset(id: preset.id)
                await reload()
                await MainActor.run {
                    pendingDeletePreset = nil
                    operationMessage = t("presets.message.deleted")
                    operationErrorMessage = nil
                }
            } catch {
                await MainActor.run {
                    pendingDeletePreset = nil
                    operationErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func restoreDefaults() {
        Task {
            do {
                _ = try await ConfigUtility.shared.restoreDefaultPresencePresets()
                await reload()
                await MainActor.run {
                    operationMessage = t("presets.message.defaults_restored")
                    operationErrorMessage = nil
                }
            } catch {
                await MainActor.run {
                    operationErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func replacePreset(_ preset: PresencePreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

private struct PresencePresetCard: View {
    let preset: PresencePreset
    let isActive: Bool
    let isPublishing: Bool
    let onPublish: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(preset.title)
                    .font(.headline)
                    .lineLimit(1)
                if isActive {
                    Text(t("presets.active_badge"))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12), in: Capsule())
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("presets.activeBadge")
                }
                if preset.isDefault {
                    Text(t("presets.default_badge"))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                        .foregroundStyle(.blue)
                }
                Spacer(minLength: 12)
                if isPublishing {
                    ProgressView()
                        .controlSize(.small)
                }
                presetActions
            }

            HStack(spacing: 8) {
                Label(preset.activityType.localizedLabel, systemImage: "gamecontroller")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(preset.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                labeledText(t("presets.details"), value: preset.details, fallback: t("presets.fallback.details"))
                labeledText(t("presets.state"), value: preset.state, fallback: t("presets.fallback.state"))
            }

            FlowLayout(spacing: 8) {
                metadata(t(preset.usesElapsedTime ? "presets.metadata.elapsed_on" : "presets.metadata.elapsed_off"))
                metadata(t(preset.resetsElapsedTimeOnPublish ? "presets.metadata.reset_on" : "presets.metadata.reset_off"))
                metadata(preset.usesParty ? t("presets.metadata.party_format").replacingOccurrences(of: "%d/%d", with: "\(preset.partyCurrent)/\(preset.partyMax)") : t("presets.metadata.party_off"))
                if let pausedElapsedDurationText {
                    metadata(pausedElapsedDurationText)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var presetActions: some View {
        HStack(spacing: 8) {
            Button(action: onPublish) {
                Label(t("presets.publish"), systemImage: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPublishing)

            Button(action: onEdit) {
                Label(t("common.edit"), systemImage: "pencil")
            }
            .buttonStyle(.bordered)

            Button(action: onDuplicate) {
                Label(t("common.duplicate"), systemImage: "plus.square.on.square")
            }
            .buttonStyle(.bordered)

            Button(role: .destructive, action: onDelete) {
                Label(t("common.delete"), systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(preset.isDefault)
            .help(preset.isDefault ? t("presets.default_delete_disabled_help") : "")
        }
        .labelStyle(.iconOnly)
    }

    private func labeledText(_ label: String, value: String, fallback: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : value)
                .font(.callout)
                .foregroundStyle(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .tertiary : .primary)
                .lineLimit(2)
        }
    }

    private func metadata(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.10), in: Capsule())
    }

    private var pausedElapsedDurationText: String? {
        guard let pausedDuration = preset.pausedElapsedDurationForDisplay else { return nil }
        return String(
            format: t("presets.metadata.paused_duration_format"),
            formatElapsedDuration(pausedDuration)
        )
    }

    private func formatElapsedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(seconds)s"
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

private struct PresencePresetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localizationManager: LocalizationManager

    let initialPreset: PresencePreset
    let onSave: (PresencePreset) async throws -> Void

    @State private var draftPreset: PresencePreset
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    init(initialPreset: PresencePreset, onSave: @escaping (PresencePreset) async throws -> Void) {
        self.initialPreset = initialPreset
        self.onSave = onSave
        _draftPreset = State(initialValue: initialPreset)
    }

    private var hasChanges: Bool {
        draftPreset != initialPreset
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sheetToolbar

                VStack(alignment: .leading, spacing: 4) {
                    Text(t("presets.editor.title"))
                        .font(.title3.weight(.semibold))
                    Text(t("presets.editor.subtitle"))
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                if let saveErrorMessage {
                    Label(saveErrorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                Form {
                    Section {
                        TextField(t("presets.editor.name"), text: $draftPreset.title)
                        Picker(t("programs.sheet.activity_type"), selection: $draftPreset.activityType) {
                            ForEach(ProgramPresenceSettings.ActivityType.allCases) { type in
                                Text(type.localizedLabel).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        TextField(t("programs.sheet.details"), text: $draftPreset.details)
                        TextField(t("programs.sheet.state_message"), text: $draftPreset.state)
                    }

                    Section(t("presets.editor.assets")) {
                        TextField(t("programs.sheet.large_image_key"), text: $draftPreset.largeImageKey)
                        TextField(t("programs.sheet.large_image_text"), text: $draftPreset.largeImageText)
                        TextField(t("programs.sheet.small_image_key"), text: $draftPreset.smallImageKey)
                        TextField(t("programs.sheet.small_image_text"), text: $draftPreset.smallImageText)
                    }

                    Section(t("presets.editor.elapsed_time")) {
                        Toggle(t("presets.editor.uses_elapsed_time"), isOn: $draftPreset.usesElapsedTime)
                        Toggle(t("presets.editor.resets_elapsed_time"), isOn: $draftPreset.resetsElapsedTimeOnPublish)
                    }

                    Section(t("presets.editor.party")) {
                        Toggle(t("presets.editor.uses_party"), isOn: $draftPreset.usesParty)
                        Stepper(value: $draftPreset.partyCurrent, in: 1...max(1, draftPreset.partyMax)) {
                            Text(t("programs.sheet.party_current") + ": \(draftPreset.partyCurrent)")
                        }
                        Stepper(value: $draftPreset.partyMax, in: max(1, draftPreset.partyCurrent)...99) {
                            Text(t("programs.sheet.party_max") + ": \(draftPreset.partyMax)")
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .frame(minWidth: 680, idealWidth: 760)
            .frame(maxHeight: 720)
        }
    }

    private var sheetToolbar: some View {
        HStack {
            Button(t("common.cancel")) { dismiss() }
                .disabled(isSaving)
            Spacer()
            Button(t("common.save")) {
                save()
            }
            .disabled(!hasChanges || isSaving || draftPreset.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.defaultAction)

            if isSaving {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        saveErrorMessage = nil

        Task {
            do {
                var presetToSave = draftPreset
                presetToSave.title = presetToSave.title.trimmingCharacters(in: .whitespacesAndNewlines)
                presetToSave.details = presetToSave.details.trimmingCharacters(in: .whitespacesAndNewlines)
                presetToSave.state = presetToSave.state.trimmingCharacters(in: .whitespacesAndNewlines)
                presetToSave.largeImageKey = presetToSave.largeImageKey.trimmingCharacters(in: .whitespacesAndNewlines)
                presetToSave.largeImageText = presetToSave.largeImageText.trimmingCharacters(in: .whitespacesAndNewlines)
                presetToSave.smallImageKey = presetToSave.smallImageKey.trimmingCharacters(in: .whitespacesAndNewlines)
                presetToSave.smallImageText = presetToSave.smallImageText.trimmingCharacters(in: .whitespacesAndNewlines)
                presetToSave.updatedAt = Date()
                try await onSave(presetToSave)
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

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if maxWidth > 0, rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth = rowWidth == 0 ? size.width : rowWidth + spacing + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }

        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth)
        return CGSize(width: maxWidth > 0 ? maxWidth : totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    PresencePresetsView()
        .environmentObject(LocalizationManager.shared)
}
