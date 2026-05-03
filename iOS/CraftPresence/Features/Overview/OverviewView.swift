import Combine
import SwiftUI

/// Dashboard-style summary of Discord state and the Rich Presence payload currently available to the app.
struct OverviewView: View {
    let activeAppName: String?
    let activeWindowTitle: String?
    let activeBundleID: String?
    let programIDs: [String]

    @ObservedObject private var discordManager = DiscordSDKManager.shared
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingDiscordConnection: Bool = false
    @State private var currentPresence: CustomPresencePreset?
    @State private var presetCount = 0
    @State private var now = Date()

    private var isTracked: Bool {
        guard let activeBundleID else { return false }
        return programIDs.contains(activeBundleID)
    }

    var body: some View {
        CPSettingsPage {
            CPHeaderCard(
                title: t("overview.title"),
                subtitle: t("overview.subtitle"),
                systemImage: "rectangle.and.text.magnifyingglass",
                tint: .pink
            )

            statusGrid
            discordConnectionPanel

            if let lastErrorMessage = discordManager.lastErrorMessage, !lastErrorMessage.isEmpty {
                errorPanel(message: lastErrorMessage)
            }

            activityPanel
        }
        .sheet(isPresented: $showingDiscordConnection) {
            DiscordConnectionView()
                .environmentObject(localizationManager)
        }
        .task {
            await reloadPresenceSummary()
        }
        .onAppear {
            Task { await reloadPresenceSummary() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await reloadPresenceSummary() }
        }
        .onReceive(NotificationCenter.default.publisher(for: ConfigUtility.settingsDidChangeNotification)) { _ in
            Task { await reloadPresenceSummary() }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsInlinePageHeader {
                Label(t("overview.title"), systemImage: "rectangle.and.text.magnifyingglass")
                    .font(.title2.weight(.bold))
                    .accessibilityIdentifier("overview.title")
            }
            if showsInlinePageHeader {
                Text(t("overview.subtitle"))
                    .foregroundStyle(.secondary)
            } else {
                Text(t("overview.subtitle"))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("overview.title")
            }
        }
    }

    private var showsInlinePageHeader: Bool {
        horizontalSizeClass != .compact
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
            value: currentPresence?.title ?? t("common.none"),
            detail: currentPresence?.details.nilIfEmpty ?? t("overview.no_active_preset")
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
            if currentPresence != nil {
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
                value: currentPresence?.title ?? t("common.none"),
                systemImage: "tag",
                valueAccessibilityIdentifier: "overview.appName"
            )

            overviewRow(
                title: t("programs.sheet.details"),
                value: currentPresence?.details.nilIfEmpty ?? t("common.none"),
                systemImage: "text.alignleft",
                valueAccessibilityIdentifier: "overview.windowTitle"
            )

            overviewRow(
                title: t("programs.sheet.state_message"),
                value: currentPresence?.state.nilIfEmpty ?? t("common.none"),
                systemImage: "bubble.left",
                valueAccessibilityIdentifier: "overview.bundleID"
            )

            overviewRow(
                title: t("overview.elapsed_time"),
                value: elapsedTimeText,
                systemImage: "clock",
                valueAccessibilityIdentifier: "overview.elapsedTime"
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
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CPStyle.cardBackground)
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
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CPStyle.cardBackground)
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

    private var elapsedTimeText: String {
        guard let currentPresence, currentPresence.usesElapsedTime else {
            return t("common.none")
        }
        guard let elapsedStartDate = currentPresence.elapsedStartDate else {
            return t("overview.elapsed_time_unavailable")
        }
        let elapsed = now.timeIntervalSince(elapsedStartDate)
        let displayElapsed = elapsed > 0 ? max(1, elapsed) : 1
        return Self.elapsedTimeFormatter.string(from: displayElapsed) ?? t("common.none")
    }

    private static let elapsedTimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

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
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CPStyle.cardBackground)
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
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
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
    private func reloadPresenceSummary() async {
        let settings = await ConfigUtility.shared.currentSettings()
        presetCount = settings.customPresencePresets.count

        if let liveActivity = try? await DiscordSDKManager.shared.currentPresenceActivity(),
           let livePresence = CustomPresencePreset(discordActivity: liveActivity) {
            currentPresence = livePresence.preservingElapsedTime(from: settings.appliedCustomPresence)
            return
        }

        if let storedPresence = settings.appliedCustomPresence ?? settings.customPresenceDraft {
            currentPresence = storedPresence
        } else {
            currentPresence = await ConfigUtility.shared.currentCustomPresenceDraft()
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
