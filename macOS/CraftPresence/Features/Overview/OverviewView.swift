import SwiftUI

/// Dashboard-style summary of Discord state and the currently detected foreground application.
struct OverviewView: View {
    let activeAppName: String?
    let activeWindowTitle: String?
    let activeBundleID: String?
    let programIDs: [String]

    @ObservedObject private var discordManager = DiscordSDKManager.shared
    @EnvironmentObject private var localizationManager: LocalizationManager

    private var isTracked: Bool {
        guard let activeBundleID else { return false }
        return programIDs.contains(activeBundleID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusGrid
                if let lastErrorMessage = discordManager.lastErrorMessage, !lastErrorMessage.isEmpty {
                    errorPanel(message: lastErrorMessage)
                }
                activityPanel
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
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
        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                metricCard(
                    title: t("overview.discord_status"),
                    systemImage: "gamecontroller",
                    accent: statusColor,
                    value: discordManager.dashboardStatus.title,
                    detail: statusDetailText
                ) {
                    statusBadge
                }

                metricCard(
                    title: t("overview.authorized_user"),
                    systemImage: "person.crop.circle",
                    accent: .blue,
                    value: discordManager.currentUser?.username ?? t("common.none"),
                    detail: discordManager.currentUser?.id ?? t("overview.user_not_loaded")
                )
            }

            GridRow {
                metricCard(
                    title: t("overview.foreground_app"),
                    systemImage: "macwindow",
                    accent: .orange,
                    value: activeAppName ?? t("common.unknown"),
                    detail: activeWindowTitle ?? t("overview.window_title_unavailable")
                )

                metricCard(
                    title: t("overview.programs_registration"),
                    systemImage: "checkmark.seal",
                    accent: isTracked ? .green : .secondary,
                    value: isTracked ? t("overview.tracked") : t("overview.unregistered"),
                    detail: activeBundleID ?? t("overview.bundle_id_unavailable")
                ) {
                    if isTracked {
                        Label(t("overview.registered_in_programs"), systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Label(t("overview.not_in_programs"), systemImage: "minus.circle")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var activityPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("overview.current_detected_info"))
                .font(.headline)

            overviewRow(
                title: t("overview.app_name"),
                value: activeAppName ?? t("common.unknown"),
                systemImage: "app.badge",
                valueAccessibilityIdentifier: "overview.appName"
            )

            overviewRow(
                title: t("overview.window_title"),
                value: activeWindowTitle ?? t("common.unknown"),
                systemImage: "text.quote",
                valueAccessibilityIdentifier: "overview.windowTitle"
            )

            overviewRow(
                title: t("overview.bundle_id"),
                value: activeBundleID ?? t("common.unknown"),
                systemImage: "barcode.viewfinder",
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

    private var statusBadge: some View {
        Text(discordManager.dashboardStatus.title)
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
}

#Preview {
    OverviewView(
        activeAppName: "Xcode",
        activeWindowTitle: "CraftPresence – DiscordSDK.swift",
        activeBundleID: "com.apple.dt.Xcode",
        programIDs: ["com.apple.dt.Xcode"]
    )
}
