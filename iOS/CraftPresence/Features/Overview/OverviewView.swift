import SwiftUI

/// Dashboard-style summary of Discord state and the manually selected Rich Presence preset.
struct OverviewView: View {
    let activeAppName: String?
    let activeWindowTitle: String?
    let activeBundleID: String?
    let programIDs: [String]

    @ObservedObject private var discordManager = DiscordSDKManager.shared
    @EnvironmentObject private var localizationManager: LocalizationManager
    @State private var showingDiscordConnection: Bool = false
    @State private var activePreset: CustomPresencePreset?
    @State private var presetCount = 0

    private var isTracked: Bool {
        guard let activeBundleID else { return false }
        return programIDs.contains(activeBundleID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusGrid
                discordConnectionPanel
                if let lastErrorMessage = discordManager.lastErrorMessage, !lastErrorMessage.isEmpty {
                    errorPanel(message: lastErrorMessage)
                }
                activityPanel
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .sheet(isPresented: $showingDiscordConnection) {
            DiscordConnectionView()
                .environmentObject(localizationManager)
        }
        .task {
            await reloadPresetSummary()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(t("overview.title"), systemImage: "rectangle.and.text.magnifyingglass")
                .font(.title2.weight(.bold))
                .accessibilityIdentifier("overview.title")
            Text(t("overview.subtitle"))
                .foregroundStyle(.secondary)
        }
    }

    private var statusGrid: some View {
        ViewThatFits(in: .horizontal) {
            Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    discordStatusCard
                    authorizedUserCard
                }

                GridRow {
                    activePresetCard
                    presetLibraryCard
                }
            }
            .frame(minWidth: 560)

            VStack(spacing: 16) {
                discordStatusCard
                authorizedUserCard
                activePresetCard
                presetLibraryCard
            }
        }
    }

    private var discordStatusCard: some View {
        metricCard(
            title: t("overview.discord_status"),
            systemImage: "gamecontroller",
            accent: statusColor,
            value: t(discordManager.dashboardStatus.localizationKey),
            detail: statusDetailText
        ) {
            statusBadge
        }
    }

    private var authorizedUserCard: some View {
        metricCard(
            title: t("overview.authorized_user"),
            systemImage: "person.crop.circle",
            accent: .blue,
            value: discordManager.currentUser?.username ?? t("common.none"),
            detail: discordManager.currentUser?.id ?? t("overview.user_not_loaded")
        )
    }

    private var activePresetCard: some View {
        metricCard(
            title: t("overview.active_preset"),
            systemImage: "paperplane.fill",
            accent: .orange,
            value: activePreset?.title ?? t("common.none"),
            detail: activePreset?.details.nilIfEmpty ?? t("overview.no_active_preset")
        )
    }

    private var presetLibraryCard: some View {
        metricCard(
            title: t("overview.preset_library"),
            systemImage: "slider.horizontal.3",
            accent: presetCount > 0 ? .green : .secondary,
            value: String(format: t("overview.preset_count_format"), presetCount),
            detail: t("overview.preset_library_detail")
        ) {
            if activePreset != nil {
                Label(t("overview.presence_live"), systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Label(t("overview.presence_idle"), systemImage: "minus.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var activityPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("overview.current_presence_info"))
                .font(.headline)

            overviewRow(
                title: t("presets.editor.title"),
                value: activePreset?.title ?? t("common.none"),
                systemImage: "tag",
                valueAccessibilityIdentifier: "overview.appName"
            )

            overviewRow(
                title: t("programs.sheet.details"),
                value: activePreset?.details.nilIfEmpty ?? t("common.none"),
                systemImage: "text.alignleft",
                valueAccessibilityIdentifier: "overview.windowTitle"
            )

            overviewRow(
                title: t("programs.sheet.state_message"),
                value: activePreset?.state.nilIfEmpty ?? t("common.none"),
                systemImage: "bubble.left",
                valueAccessibilityIdentifier: "overview.bundleID"
            )

            overviewRow(
                title: t("overview.discord_authorization"),
                value: authorizationText,
                systemImage: "lock.shield",
                valueAccessibilityIdentifier: "overview.authorization"
            )
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var discordConnectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("overview.discord_connection"))
                .font(.headline)

            Text(t("overview.discord_connection_description"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(discordConnectionButtonTitle) {
                showingDiscordConnection = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var statusBadge: some View {
        Text(t(discordManager.dashboardStatus.localizationKey))
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.14), in: Capsule())
            .foregroundStyle(statusColor)
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

    private var statusDetailText: String {
        switch discordManager.dashboardStatus {
        case .notConfigured:
            return t("overview.status_detail.not_configured")
        case .configured:
            return t("overview.status_detail.configured")
        case .authorizing:
            return t("overview.status_detail.authorizing")
        case .connecting:
            return t("overview.status_detail.connecting")
        case .ready:
            return t("overview.status_detail.ready")
        case .unauthorized:
            return t("overview.status_detail.unauthorized")
        case .failed:
            return t("overview.status_detail.failed")
        }
    }

    private var authorizationText: String {
        switch discordManager.authorizationStatus {
        case .authorized:
            return t("common.authorized")
        case .unauthorized:
            return t("common.unauthorized")
        case .unknown:
            return t("common.unknown")
        }
    }

    private var discordConnectionButtonTitle: String {
        switch discordManager.dashboardStatus {
        case .ready:
            return t("overview.manage_discord_connection")
        case .authorizing, .connecting:
            return t("discord.connection.connecting")
        case .configured, .notConfigured, .unauthorized, .failed:
            return t("overview.connect_discord")
        }
    }

    /// Builds a highlighted status card with an optional accessory view in the trailing corner.
    private func metricCard<Accessory: View>(
        title: String,
        systemImage: String,
        accent: Color,
        value: String,
        detail: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Spacer(minLength: 12)
                accessory()
            }

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    /// Convenience overload for a metric card without a trailing accessory.
    private func metricCard(
        title: String,
        systemImage: String,
        accent: Color,
        value: String,
        detail: String
    ) -> some View {
        metricCard(
            title: title,
            systemImage: systemImage,
            accent: accent,
            value: value,
            detail: detail
        ) {
            EmptyView()
        }
    }

    /// Presents the latest Discord-related error message in a prominent warning panel.
    private func errorPanel(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(t("overview.recent_error"), systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.red.opacity(0.18), lineWidth: 1)
        )
    }

    /// Displays a single key-value row inside the activity summary panel.
    private func overviewRow(
        title: String,
        value: String,
        systemImage: String,
        valueAccessibilityIdentifier: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .accessibilityIdentifier(valueAccessibilityIdentifier)
            }
            Spacer(minLength: 0)
        }
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }

    @MainActor
    private func reloadPresetSummary() async {
        let settings = await ConfigUtility.shared.currentSettings()
        presetCount = settings.customPresencePresets.count
        if let id = settings.activeCustomPresencePresetID {
            activePreset = settings.customPresencePresets.first { $0.id == id }
        } else {
            activePreset = nil
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
