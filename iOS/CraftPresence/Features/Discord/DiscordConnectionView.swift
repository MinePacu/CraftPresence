import SwiftUI

/// User-facing Discord connection screen used for first-run onboarding and later account management.
struct DiscordConnectionView: View {
    enum Mode {
        case onboarding
        case standalone
    }

    let mode: Mode
    let onFinish: (() -> Void)?
    let onSkip: (() -> Void)?

    @ObservedObject private var discordManager = DiscordSDKManager.shared
    @EnvironmentObject private var localizationManager: LocalizationManager

    @State private var isLoading: Bool = false
    @State private var actionMessage: String = ""

    init(mode: Mode = .standalone, onFinish: (() -> Void)? = nil, onSkip: (() -> Void)? = nil) {
        self.mode = mode
        self.onFinish = onFinish
        self.onSkip = onSkip
    }

    var body: some View {
        content
            .task {
                refreshUserIfPossible()
            }
            .onChange(of: discordManager.dashboardStatus) { _, newStatus in
                guard mode == .onboarding, newStatus == .ready else { return }
                onFinish?()
            }
            .onChange(of: discordManager.authorizationStatus) { _, newStatus in
                guard mode == .onboarding, newStatus == .authorized else { return }
                onFinish?()
            }
    }

    @ViewBuilder
    private var content: some View {
        if mode == .onboarding {
            onboardingContent
        } else {
            standaloneContent
        }
    }

    private var onboardingContent: some View {
        CPSettingsPage(maximumContentWidth: 640) {
            onboardingHero
            statusCard
            requirementsCard
            if let user = discordManager.currentUser {
                accountCard(user: user)
            }
            messageContent
            actionSection
        }
    }

    private var standaloneContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusCard
                requirementsCard
                if let user = discordManager.currentUser {
                    accountCard(user: user)
                }
                messageContent
                actionSection
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, minHeight: mode == .onboarding ? 500 : 420)
#if os(macOS) || targetEnvironment(macCatalyst)
        .frame(minWidth: mode == .onboarding ? 540 : 480)
#endif
    }

    @ViewBuilder
    private var messageContent: some View {
        if shouldShowRecentError, let lastErrorMessage = discordManager.lastErrorMessage, !lastErrorMessage.isEmpty {
            messageCard(
                title: t("discord.connection.error_title"),
                message: lastErrorMessage,
                tint: .red
            )
        } else if !actionMessage.isEmpty {
            messageCard(
                title: t("discord.connection.message_title"),
                message: actionMessage,
                tint: .secondary
            )
        }
    }

    private var onboardingHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 38, weight: .semibold))
                .frame(width: 72, height: 72)
                .background(.indigo.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                Text(t("discord.onboarding.title"))
                    .font(.largeTitle.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(t("discord.onboarding.subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(t("discord.onboarding.priority"), systemImage: "sparkles")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.indigo)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                mode == .onboarding ? t("discord.onboarding.title") : t("discord.connection.title"),
                systemImage: "gamecontroller.fill"
            )
            .font(.title2.weight(.bold))

            Text(mode == .onboarding ? t("discord.onboarding.subtitle") : t("discord.connection.subtitle"))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("discord.connection.status"))
                        .font(.headline)
                    Text(statusDescription)
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

            Divider()

            infoRow(
                title: t("discord.connection.application_id"),
                value: maskedApplicationID ?? t("discord.connection.not_configured")
            )
            infoRow(
                title: t("discord.connection.authorization"),
                value: authorizationText
            )
            infoRow(
                title: t("discord.connection.account"),
                value: discordManager.currentUser?.username ?? t("common.none")
            )
        }
        .padding(18)
        .background(cardBackground)
    }

    private var requirementsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("discord.connection.requirements_title"))
                .font(.headline)
            requirementRow(t("discord.connection.requirement.desktop"))
            requirementRow(t("discord.connection.requirement.login"))
            requirementRow(t("discord.connection.requirement.permission"))
        }
        .padding(18)
        .background(cardBackground)
    }

    private func accountCard(user: DiscordUser) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("discord.connection.account_title"))
                .font(.headline)
            infoRow(title: t("discord.connection.username"), value: user.username)
            infoRow(title: t("discord.connection.user_id"), value: user.id)
        }
        .padding(18)
        .background(cardBackground)
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("discord.connection.actions_title"))
                .font(.headline)

            ViewThatFits(in: .horizontal) {
                actionButtons
                VStack(alignment: .leading, spacing: 12) {
                    actionButtons
                }
            }

            if mode == .onboarding {
                Button(t("discord.onboarding.skip")) {
                    (onSkip ?? onFinish)?()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if mode == .onboarding {
                Button(primaryActionTitle) {
                    Task {
                        await performPrimaryAction()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || primaryActionDisabled)

                if discordManager.dashboardStatus == .ready {
                    Button(t("discord.onboarding.continue")) {
                        onFinish?()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button(primaryActionTitle) {
                    Task {
                        await performPrimaryAction()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || primaryActionDisabled)

                Button(t("discord.connection.refresh_user")) {
                    Task {
                        await reloadUser()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading || !canRefreshUser)

                if discordManager.authorizationStatus == .authorized {
                    Button(t("discord.connection.disconnect")) {
                        Task {
                            await disconnect()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
            }
        }
    }

    private var statusDescription: String {
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

    private var maskedApplicationID: String? {
        let rawValue = DiscordAppConfig.applicationId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawValue.isEmpty else { return nil }

        if rawValue.count <= 6 {
            return String(repeating: "*", count: rawValue.count)
        }

        return String(rawValue.prefix(3)) + String(repeating: "*", count: rawValue.count - 6) + String(rawValue.suffix(3))
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

    private var primaryActionTitle: String {
        switch discordManager.dashboardStatus {
        case .ready:
            return t("discord.connection.connected")
        case .authorizing, .connecting:
            return t("discord.connection.connecting")
        case .failed:
            return t("discord.connection.retry")
        case .configured, .notConfigured, .unauthorized:
            return t("discord.connection.connect")
        }
    }

    private var primaryActionDisabled: Bool {
        switch discordManager.dashboardStatus {
        case .ready, .authorizing, .connecting:
            return true
        case .configured, .notConfigured, .unauthorized, .failed:
            return false
        }
    }

    private var canRefreshUser: Bool {
        discordManager.authorizationStatus == .authorized
    }

    private var shouldShowRecentError: Bool {
        discordManager.authorizationStatus != .authorized && discordManager.dashboardStatus != .ready
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.secondary.opacity(0.08))
    }

    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
    }

    private func requirementRow(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle")
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func messageCard(title: String, message: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(tint)
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }

    private func refreshUserIfPossible() {
        guard discordManager.authorizationStatus == .authorized else { return }
        Task {
            await reloadUser()
        }
    }

    private func ensureConfigured() throws {
        let applicationID = DiscordAppConfig.applicationId
        if let validationError = DiscordAppConfig.validationError(for: applicationID) {
            throw validationError
        }

        discordManager.configure(applicationId: applicationID, autoAuthorize: false)
    }

    private func performPrimaryAction() async {
        actionMessage = ""
        isLoading = true
        defer { isLoading = false }

        do {
            try ensureConfigured()
            _ = try await discordManager.authorizeIfNeeded()
            actionMessage = t("discord.connection.connect_success")
        } catch {
            actionMessage = error.localizedDescription
        }
    }

    private func reloadUser() async {
        actionMessage = ""
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await discordManager.currentUser()
            actionMessage = t("discord.connection.refresh_success")
        } catch {
            actionMessage = error.localizedDescription
        }
    }

    private func disconnect() async {
        actionMessage = ""
        isLoading = true
        defer { isLoading = false }

        do {
            try await discordManager.logout()
            actionMessage = t("discord.connection.disconnect_success")
        } catch {
            actionMessage = error.localizedDescription
        }
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}
