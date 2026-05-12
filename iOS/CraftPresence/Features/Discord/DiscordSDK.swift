import Foundation
import Combine
import Security
#if canImport(discord_partner_sdk)
import discord_partner_sdk
#endif

/// Resolves Discord application settings from app configuration.
enum DiscordAppConfig {
    /// Discord Developer Portal application ID from Info.plist or the process environment.
    nonisolated static var applicationId: String? {
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "APPLICATION_ID") as? String,
           !plistValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plistValue
        }
        if let env = ProcessInfo.processInfo.environment["APPLICATION_ID"],
           !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env
        }
        return nil
    }

    /// Returns an SDK configuration error when the application ID is missing or malformed.
    ///
    /// - Parameter applicationId: Discord Developer Portal application ID to validate.
    nonisolated static func validationError(for applicationId: String?) -> DiscordSDKError? {
        let normalizedId = applicationId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalizedId.isEmpty else {
            return .invalidApplicationID("APPLICATION_ID is missing.")
        }
        guard normalizedId != "YOUR_APPLICATION_ID" else {
            return .invalidApplicationID("APPLICATION_ID still uses the placeholder value.")
        }
        guard CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: normalizedId)) else {
            return .invalidApplicationID("APPLICATION_ID must contain only numeric characters.")
        }
        return nil
    }
}

/// Main-actor manager for Discord authorization, token storage, and Rich Presence updates on iOS.
@MainActor
final class DiscordSDKManager: ObservableObject {
    /// Shared Discord SDK manager used by app features.
    static let shared = DiscordSDKManager()

    /// High-level authorization state exposed to SwiftUI.
    enum AuthorizationStatus: Sendable, Equatable {
        /// Discord authorization is valid and user data is available or being loaded.
        case authorized

        /// Discord authorization is missing, expired, revoked, or refused.
        case unauthorized

        /// Authorization has not been checked yet.
        case unknown
    }

    /// Dashboard-facing setup, authorization, and connection state.
    enum DashboardStatus: Sendable, Equatable {
        /// Discord SDK has no valid application ID.
        case notConfigured

        /// Discord SDK has a valid application ID but is not yet connected.
        case configured

        /// Discord authorization is currently running.
        case authorizing

        /// Discord SDK is connecting or reconnecting.
        case connecting

        /// Discord SDK is authorized and ready for Rich Presence calls.
        case ready

        /// Discord SDK is configured but not authorized.
        case unauthorized

        /// Discord SDK setup, authorization, or connection failed.
        case failed

        /// Localization key used for the visible dashboard status label.
        var localizationKey: String {
            switch self {
            case .notConfigured: return "discord.status.not_configured"
            case .configured: return "discord.status.configured"
            case .authorizing: return "discord.status.authorizing"
            case .connecting: return "discord.status.connecting"
            case .ready: return "discord.status.ready"
            case .unauthorized: return "discord.status.unauthorized"
            case .failed: return "discord.status.failed"
            }
        }
    }

    /// Current high-level authorization status for the Discord session.
    @Published private(set) var authorizationStatus: AuthorizationStatus = .unknown

    /// Current authorized Discord user, when user data is available.
    @Published private(set) var currentUser: DiscordUser?

    /// Dashboard-facing lifecycle state.
    @Published private(set) var dashboardStatus: DashboardStatus = .notConfigured

    /// Last SDK or configuration error intended for UI display.
    @Published private(set) var lastErrorMessage: String?

    /// Last validated Discord application ID used to configure the SDK.
    private var configuredApplicationId: String?

    /// Keychain-backed OAuth token storage.
    private let tokenStore = DiscordTokenStore()
    #if canImport(discord_partner_sdk)
    /// Opaque native Discord Social SDK client handle.
    private var client = Discord_Client(opaque: nil)

    /// Whether `client` has been initialized and must be dropped before replacement.
    private var isClientInitialized = false

    /// Task that regularly pumps native Discord SDK callbacks.
    private var callbackPumpTask: Task<Void, Never>?
    #endif

    /// Prevents external construction so all callers share one SDK session.
    private init() {}

    /// Releases native Discord SDK resources when the shared manager is torn down.
    deinit {
        #if canImport(discord_partner_sdk)
        callbackPumpTask?.cancel()
        if isClientInitialized {
            Discord_Client_Disconnect(&client)
            Discord_Client_Drop(&client)
        }
        #endif
    }

    /// Configures the Discord Social SDK for an application ID.
    ///
    /// - Parameters:
    ///   - applicationId: Discord Developer Portal application ID. Defaults to app configuration.
    ///   - autoAuthorize: Whether to start authorization immediately after configuration.
    func configure(applicationId: String? = DiscordAppConfig.applicationId, autoAuthorize: Bool = true) {
        if let validationError = DiscordAppConfig.validationError(for: applicationId) {
            #if canImport(discord_partner_sdk)
            resetSocialSDK()
            #endif
            configuredApplicationId = nil
            authorizationStatus = .unauthorized
            currentUser = nil
            dashboardStatus = .failed
            lastErrorMessage = validationError.localizedDescription
            return
        }

        configuredApplicationId = applicationId?.trimmingCharacters(in: .whitespacesAndNewlines)
        authorizationStatus = .unauthorized
        currentUser = nil
        dashboardStatus = .configured
        lastErrorMessage = nil

        #if canImport(discord_partner_sdk)
        configureSocialSDK(applicationId: configuredApplicationId)
        #endif

        if autoAuthorize {
            authorizeIfNeeded()
        } else if tokenStore.load() != nil {
            restoreAuthorizationIfPossible()
        }
    }

    /// Ensures a Discord user is authorized, using a saved token or interactive authorization.
    ///
    /// - Parameter completion: Completion called with the authorized user or SDK error.
    func authorizeIfNeeded(completion: ((Result<DiscordUser, DiscordSDKError>) -> Void)? = nil) {
        authorizeIfNeeded(allowInteractiveAuthorization: true, completion: completion)
    }

    /// Attempts silent authorization from saved tokens without opening an interactive flow.
    ///
    /// - Parameter completion: Completion called with the authorized user or SDK error.
    func restoreAuthorizationIfPossible(completion: ((Result<DiscordUser, DiscordSDKError>) -> Void)? = nil) {
        authorizeIfNeeded(allowInteractiveAuthorization: false, completion: completion)
    }

    /// Performs saved-token, refresh-token, or interactive authorization.
    ///
    /// - Parameters:
    ///   - allowInteractiveAuthorization: Whether this call may open Discord's interactive flow.
    ///   - completion: Completion called with the authorized user or SDK error.
    private func authorizeIfNeeded(
        allowInteractiveAuthorization: Bool,
        completion: ((Result<DiscordUser, DiscordSDKError>) -> Void)? = nil
    ) {
        #if canImport(discord_partner_sdk)
        guard isClientInitialized else {
            completion?(.failure(.notConfigured))
            return
        }
        guard let applicationId = normalizedApplicationId else {
            completion?(.failure(.notConfigured))
            return
        }

        dashboardStatus = .authorizing
        lastErrorMessage = nil

        Task {
            do {
                let savedToken = tokenStore.load()
                if let savedToken {
                    if savedToken.isAccessTokenUsable {
                        try await updateSDKToken(savedToken)
                        let user = try await fetchAuthenticatedUser(using: savedToken)
                        await MainActor.run {
                            authorizationStatus = .authorized
                            currentUser = user
                            dashboardStatus = .ready
                            lastErrorMessage = nil
                            completion?(.success(user))
                        }
                        return
                    }

                    if !savedToken.refreshToken.isEmpty {
                        let refreshed = try await refreshToken(savedToken.refreshToken, applicationId: applicationId)
                        tokenStore.save(refreshed)
                        try await updateSDKToken(refreshed)
                        let user = try await fetchAuthenticatedUser(using: refreshed)
                        await MainActor.run {
                            authorizationStatus = .authorized
                            currentUser = user
                            dashboardStatus = .ready
                            lastErrorMessage = nil
                            completion?(.success(user))
                        }
                        return
                    }
                }

                guard allowInteractiveAuthorization else {
                    await MainActor.run {
                        authorizationStatus = .unauthorized
                        dashboardStatus = .unauthorized
                        lastErrorMessage = nil
                        completion?(.failure(.unauthorized))
                    }
                    return
                }

                let token = try await runOAuthAuthorization(applicationId: applicationId)
                tokenStore.save(token)
                try await updateSDKToken(token)
                let user = try await fetchAuthenticatedUser(using: token)
                await MainActor.run {
                    authorizationStatus = .authorized
                    currentUser = user
                    dashboardStatus = .ready
                    lastErrorMessage = nil
                    completion?(.success(user))
                }
            } catch {
                await MainActor.run {
                    authorizationStatus = .unauthorized
                    dashboardStatus = .failed
                    lastErrorMessage = error.localizedDescription
                    completion?(.failure((error as? DiscordSDKError) ?? .sdk(error.localizedDescription)))
                }
            }
        }
        #else
        completion?(.failure(.unsupportedPlatform))
        #endif
    }

    /// Logs out, revokes the active token when possible, and clears saved authorization.
    ///
    /// - Parameter completion: Completion called after logout or token revocation.
    func logout(completion: ((Result<Void, DiscordSDKError>) -> Void)? = nil) {
        #if canImport(discord_partner_sdk)
        let savedToken = tokenStore.load()
        tokenStore.delete()
        if let applicationId = normalizedApplicationId,
           let token = savedToken?.accessToken,
           !token.isEmpty,
           isClientInitialized {
            revokeToken(token, applicationId: applicationId) { [weak self] result in
                self?.finishLocalLogout()
                completion?(result)
            }
            return
        }
        finishLocalLogout()
        #else
        tokenStore.delete()
        authorizationStatus = .unauthorized
        currentUser = nil
        dashboardStatus = configuredApplicationId == nil ? .notConfigured : .unauthorized
        lastErrorMessage = nil
        #endif
        completion?(.success(()))
    }

    /// Fetches the current Discord user from the active authorization.
    ///
    /// - Parameter completion: Completion called with the current Discord user or SDK error.
    func fetchCurrentUser(completion: ((Result<DiscordUser, DiscordSDKError>) -> Void)? = nil) {
        #if canImport(discord_partner_sdk)
        if let token = tokenStore.load(), !token.accessToken.isEmpty {
            Task {
                do {
                    let user = try await fetchAuthenticatedUser(using: token)
                    await MainActor.run {
                        currentUser = user
                        authorizationStatus = .authorized
                        dashboardStatus = .ready
                        lastErrorMessage = nil
                        completion?(.success(user))
                    }
                } catch {
                    await MainActor.run {
                        completion?(.failure((error as? DiscordSDKError) ?? .sdk(error.localizedDescription)))
                    }
                }
            }
            return
        }

        guard isClientInitialized else {
            completion?(.failure(.notConfigured))
            return
        }

        guard let user = currentUserFromAuthenticatedClient() else {
            completion?(.failure(.unauthorized))
            return
        }

        currentUser = user
        authorizationStatus = .authorized
        dashboardStatus = .ready
        lastErrorMessage = nil
        completion?(.success(user))
        #else
        completion?(.failure(.unsupportedPlatform))
        #endif
    }

    /// Publishes a Rich Presence activity to Discord.
    ///
    /// Empty optional strings are omitted from the native SDK payload.
    ///
    /// - Parameters:
    ///   - name: Activity title shown as the primary Rich Presence label.
    ///   - state: Short status line, usually the current mode or context.
    ///   - details: Longer status line, usually the item, track, or screen name.
    ///   - largeImageKey: Discord Developer Portal key for the large image.
    ///   - largeImageText: Tooltip text for the large image.
    ///   - smallImageKey: Discord Developer Portal key for the small image.
    ///   - smallImageText: Tooltip text for the small image.
    ///   - partyID: Stable party identifier for Discord party metadata.
    ///   - partyCurrent: Current party size.
    ///   - partyMax: Maximum party size.
    ///   - start: Start time used for elapsed time displays.
    ///   - end: End time used for remaining time displays.
    ///   - activityType: Discord Rich Presence activity category.
    ///   - completion: Completion called after Discord accepts or rejects the update.
    func updateActivity(
        name: String?,
        state: String? = nil,
        details: String? = nil,
        largeImageKey: String? = nil,
        largeImageText: String? = nil,
        smallImageKey: String? = nil,
        smallImageText: String? = nil,
        partyID: String? = nil,
        partyCurrent: Int? = nil,
        partyMax: Int? = nil,
        start: Date? = nil,
        end: Date? = nil,
        activityType: DiscordActivity.ActivityType = .playing,
        completion: ((Result<Void, DiscordSDKError>) -> Void)? = nil
    ) {
        #if canImport(discord_partner_sdk)
        guard isClientInitialized else {
            completion?(.failure(.notConfigured))
            return
        }

        var activity = Discord_Activity(opaque: nil)
        Discord_Activity_Init(&activity)
        defer { Discord_Activity_Drop(&activity) }

        withDiscordString(name?.nilIfEmpty ?? "CraftPresence") {
            Discord_Activity_SetName(&activity, $0)
        }
        Discord_Activity_SetType(&activity, activityType.socialSDKActivityType)
        Discord_Activity_SetSupportedPlatforms(&activity, Discord_ActivityGamePlatforms_IOS)

        setOptionalString(state, on: &activity, setter: Discord_Activity_SetState)
        setOptionalString(details, on: &activity, setter: Discord_Activity_SetDetails)

        var hasAssets = false
        var assets = Discord_ActivityAssets(opaque: nil)
        Discord_ActivityAssets_Init(&assets)
        defer { Discord_ActivityAssets_Drop(&assets) }
        if setOptionalString(largeImageKey, on: &assets, setter: Discord_ActivityAssets_SetLargeImage) { hasAssets = true }
        if setOptionalString(largeImageText, on: &assets, setter: Discord_ActivityAssets_SetLargeText) { hasAssets = true }
        if setOptionalString(smallImageKey, on: &assets, setter: Discord_ActivityAssets_SetSmallImage) { hasAssets = true }
        if setOptionalString(smallImageText, on: &assets, setter: Discord_ActivityAssets_SetSmallText) { hasAssets = true }
        if hasAssets {
            Discord_Activity_SetAssets(&activity, &assets)
        }

        if start != nil || end != nil {
            var timestamps = Discord_ActivityTimestamps(opaque: nil)
            Discord_ActivityTimestamps_Init(&timestamps)
            defer { Discord_ActivityTimestamps_Drop(&timestamps) }
            if let start {
                Discord_ActivityTimestamps_SetStart(&timestamps, Self.discordTimestamp(from: start))
            }
            if let end {
                Discord_ActivityTimestamps_SetEnd(&timestamps, Self.discordTimestamp(from: end))
            }
            Discord_Activity_SetTimestamps(&activity, &timestamps)
        }

        if let partyID = partyID?.nilIfEmpty,
           let partyCurrent,
           let partyMax,
           partyCurrent > 0,
           partyMax >= partyCurrent {
            var party = Discord_ActivityParty(opaque: nil)
            Discord_ActivityParty_Init(&party)
            defer { Discord_ActivityParty_Drop(&party) }
            withDiscordString(partyID) {
                Discord_ActivityParty_SetId(&party, $0)
            }
            Discord_ActivityParty_SetCurrentSize(&party, Int32(partyCurrent))
            Discord_ActivityParty_SetMaxSize(&party, Int32(partyMax))
            Discord_Activity_SetParty(&activity, &party)
        }

        let box = DiscordVoidCallbackBox(completion: completion)
        Discord_Client_UpdateRichPresence(
            &client,
            &activity,
            { result, userData in
                guard let userData else { return }
                let box = Unmanaged<DiscordVoidCallbackBox>.fromOpaque(userData).takeUnretainedValue()
                let isSuccessful = result.map { Discord_ClientResult_Successful($0) } ?? false
                let message = result.flatMap { DiscordSDKManager.resultErrorMessage($0) }

                DispatchQueue.main.async {
                    if isSuccessful {
                        box.completion?(.success(()))
                    } else {
                        box.completion?(.failure(.sdk(message?.nilIfEmpty ?? "Discord SDK request failed.")))
                    }
                }
            },
            { pointer in
                guard let pointer else { return }
                Unmanaged<DiscordVoidCallbackBox>.fromOpaque(pointer).release()
            },
            Unmanaged.passRetained(box).toOpaque()
        )
        dashboardStatus = .ready
        lastErrorMessage = nil
        #else
        completion?(.failure(.unsupportedPlatform))
        #endif
    }

    /// Clears the currently published Rich Presence activity.
    ///
    /// - Parameter completion: Completion called after the clear request is sent.
    func clearActivity(completion: ((Result<Void, DiscordSDKError>) -> Void)? = nil) {
        #if canImport(discord_partner_sdk)
        guard isClientInitialized else {
            completion?(.failure(.notConfigured))
            return
        }
        Discord_Client_ClearRichPresence(&client)
        #endif
        completion?(.success(()))
    }

    /// Async wrapper around `authorizeIfNeeded(completion:)`.
    func authorizeIfNeeded() async throws -> DiscordUser {
        try await withCheckedThrowingContinuation { continuation in
            authorizeIfNeeded { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Async wrapper around `restoreAuthorizationIfPossible(completion:)`.
    func restoreAuthorizationIfPossible() async throws -> DiscordUser {
        try await withCheckedThrowingContinuation { continuation in
            restoreAuthorizationIfPossible { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Async wrapper around `fetchCurrentUser(completion:)`.
    func currentUser() async throws -> DiscordUser {
        try await withCheckedThrowingContinuation { continuation in
            fetchCurrentUser { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Returns the activity currently visible on the authenticated Discord user, when available.
    func currentPresenceActivity() async throws -> DiscordActivity? {
        if authorizationStatus != .authorized {
            Log.d(
                "Restoring authorization before reading current Presence. status=\(authorizationStatus)",
                category: "PresencePriority"
            )
            _ = try await restoreAuthorizationIfPossible()
        }
        #if canImport(discord_partner_sdk)
        let activity = currentPresenceActivityFromAuthenticatedClient()
        Log.d(
            "Read current Discord Presence: \(activity?.debugSummary ?? "nil")",
            category: "PresencePriority"
        )
        return activity
        #else
        throw DiscordSDKError.unsupportedPlatform
        #endif
    }

    /// Async wrapper around `logout(completion:)`.
    func logout() async throws {
        try await withCheckedThrowingContinuation { continuation in
            logout { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Async wrapper around the callback-based Rich Presence update API.
    ///
    /// - Parameters:
    ///   - name: Activity title shown as the primary Rich Presence label.
    ///   - state: Short status line, usually the current mode or context.
    ///   - details: Longer status line, usually the item, track, or screen name.
    ///   - largeImageKey: Discord Developer Portal key for the large image.
    ///   - largeImageText: Tooltip text for the large image.
    ///   - smallImageKey: Discord Developer Portal key for the small image.
    ///   - smallImageText: Tooltip text for the small image.
    ///   - partyID: Stable party identifier for Discord party metadata.
    ///   - partyCurrent: Current party size.
    ///   - partyMax: Maximum party size.
    ///   - start: Start time used for elapsed time displays.
    ///   - end: End time used for remaining time displays.
    ///   - activityType: Discord Rich Presence activity category.
    func updateActivity(
        name: String?,
        state: String? = nil,
        details: String? = nil,
        largeImageKey: String? = nil,
        largeImageText: String? = nil,
        smallImageKey: String? = nil,
        smallImageText: String? = nil,
        partyID: String? = nil,
        partyCurrent: Int? = nil,
        partyMax: Int? = nil,
        start: Date? = nil,
        end: Date? = nil,
        activityType: DiscordActivity.ActivityType = .playing
    ) async throws {
        if authorizationStatus != .authorized {
            _ = try await restoreAuthorizationIfPossible()
        }

        try await withCheckedThrowingContinuation { continuation in
            updateActivity(
                name: name,
                state: state,
                details: details,
                largeImageKey: largeImageKey,
                largeImageText: largeImageText,
                smallImageKey: smallImageKey,
                smallImageText: smallImageText,
                partyID: partyID,
                partyCurrent: partyCurrent,
                partyMax: partyMax,
                start: start,
                end: end,
                activityType: activityType
            ) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Publishes a previously built Presence payload.
    ///
    /// - Parameter payload: App-owned Rich Presence payload to send to Discord.
    func updateActivity(_ payload: AppliedPresencePayload) async throws {
        try await updateActivity(
            name: payload.name,
            state: payload.state,
            details: payload.details,
            largeImageKey: payload.largeImageKey,
            largeImageText: payload.largeImageText,
            smallImageKey: payload.smallImageKey,
            smallImageText: payload.smallImageText,
            partyID: payload.partyID,
            partyCurrent: payload.partyCurrent,
            partyMax: payload.partyMax,
            start: payload.start,
            end: payload.end,
            activityType: payload.activityType.discordActivityType
        )
    }

    /// Publishes and records the last app-owned Presence payload after Discord accepts it.
    ///
    /// - Parameter payload: App-owned Rich Presence payload to persist for priority restoration.
    func publishAppliedPresence(_ payload: AppliedPresencePayload) async throws {
        Log.d("Publishing applied Presence: \(payload.debugSummary)", category: "PresencePriority")
        try await updateActivity(payload)
        _ = try await ConfigUtility.shared.setAppliedPresence(payload)
        Log.d("Stored applied Presence after publish: \(payload.debugSummary)", category: "PresencePriority")
    }

    /// Clears Discord Rich Presence and removes the priority restoration target.
    func clearAppliedPresence() async throws {
        let currentPayload = await ConfigUtility.shared.currentAppliedPresence()
        Log.d(
            "Clearing applied Presence unconditionally. stored=\(currentPayload?.debugSummary ?? "nil")",
            category: "PresencePriority"
        )
        try await clearActivity()
        _ = try await ConfigUtility.shared.setAppliedPresence(nil)
        Log.d("Cleared applied Presence storage", category: "PresencePriority")
    }

    /// Clears Discord Rich Presence only if the saved app-owned Presence belongs to the supplied source.
    func clearAppliedPresence(ifOwnedBy source: AppliedPresenceSource) async throws {
        let currentPayload = await ConfigUtility.shared.currentAppliedPresence()
        guard currentPayload?.source == source else {
            Log.d(
                "Skipped guarded clear for source=\(source.rawValue). stored=\(currentPayload?.debugSummary ?? "nil")",
                category: "PresencePriority"
            )
            return
        }
        Log.d(
            "Guarded clear matched source=\(source.rawValue). stored=\(currentPayload?.debugSummary ?? "nil")",
            category: "PresencePriority"
        )
        try await clearAppliedPresence()
    }

    /// Async wrapper around `clearActivity(completion:)`.
    func clearActivity() async throws {
        try await withCheckedThrowingContinuation { continuation in
            clearActivity { result in
                continuation.resume(with: result)
            }
        }
    }

    #if canImport(discord_partner_sdk)
    /// Initializes the native Discord Social SDK client and starts connection callbacks.
    ///
    /// - Parameter applicationId: Valid Discord Developer Portal application ID string.
    private func configureSocialSDK(applicationId: String?) {
        guard let applicationId, let numericApplicationId = UInt64(applicationId) else { return }

        resetSocialSDK()

        Discord_Client_Init(&client)
        isClientInitialized = true
        startCallbackPump()
        Discord_Client_SetApplicationId(&client, numericApplicationId)
        Discord_Client_SetStatusChangedCallback(
            &client,
            { status, error, detail, _ in
                DispatchQueue.main.async {
                    DiscordSDKManager.shared.handleStatusChanged(status: status, error: error, detail: detail)
                }
            },
            nil,
            nil
        )
        Discord_Client_SetTokenExpirationCallback(
            &client,
            { _ in
                DispatchQueue.main.async {
                    Task {
                        await DiscordSDKManager.shared.refreshStoredTokenIfPossible()
                    }
                }
            },
            nil,
            nil
        )
        Discord_Client_Connect(&client)
        dashboardStatus = .connecting
    }

    /// Disconnects and drops the native Discord Social SDK client if it is active.
    private func resetSocialSDK() {
        stopCallbackPump()
        if isClientInitialized {
            Discord_Client_Disconnect(&client)
            Discord_Client_Drop(&client)
            client = Discord_Client(opaque: nil)
            isClientInitialized = false
        }
    }

    /// Starts the callback pump required by the Discord Social SDK.
    private func startCallbackPump() {
        stopCallbackPump()
        callbackPumpTask = Task { @MainActor [weak self] in
            while let self, self.isClientInitialized, !Task.isCancelled {
                Discord_RunCallbacks()
                try? await Task.sleep(nanoseconds: 33_000_000)
            }
        }
    }

    /// Stops the Discord callback pump task.
    private func stopCallbackPump() {
        callbackPumpTask?.cancel()
        callbackPumpTask = nil
    }

    /// Clears local authorization state and releases native SDK resources after logout.
    private func finishLocalLogout() {
        authorizationStatus = .unauthorized
        currentUser = nil
        dashboardStatus = configuredApplicationId == nil ? .notConfigured : .unauthorized
        lastErrorMessage = nil
        resetSocialSDK()
    }

    /// Numeric Discord application ID used by native SDK functions.
    private var normalizedApplicationId: UInt64? {
        guard let configuredApplicationId,
              let applicationId = UInt64(configuredApplicationId) else {
            return nil
        }
        return applicationId
    }

    /// Runs PKCE OAuth authorization and exchanges the returned code for tokens.
    ///
    /// - Parameter applicationId: Numeric Discord Developer Portal application ID.
    private func runOAuthAuthorization(applicationId: UInt64) async throws -> DiscordOAuthToken {
        let authorization = try await requestAuthorizationCode(applicationId: applicationId)
        return try await exchangeAuthorizationCode(
            authorization.code,
            codeVerifier: authorization.codeVerifier,
            redirectURI: authorization.redirectURI,
            applicationId: applicationId
        )
    }

    /// Requests an authorization code and redirect URI from Discord using PKCE.
    ///
    /// - Parameter applicationId: Numeric Discord Developer Portal application ID used as the OAuth client ID.
    private func requestAuthorizationCode(applicationId: UInt64) async throws -> DiscordAuthorizationResponse {
        try await withCheckedThrowingContinuation { continuation in
            var verifier = Discord_AuthorizationCodeVerifier(opaque: nil)
            Discord_Client_CreateAuthorizationCodeVerifier(&client, &verifier)
            defer { Discord_AuthorizationCodeVerifier_Drop(&verifier) }

            var challenge = Discord_AuthorizationCodeChallenge(opaque: nil)
            Discord_AuthorizationCodeVerifier_Challenge(&verifier, &challenge)
            defer { Discord_AuthorizationCodeChallenge_Drop(&challenge) }

            var verifierString = Discord_String(ptr: nil, size: 0)
            Discord_AuthorizationCodeVerifier_Verifier(&verifier, &verifierString)
            let codeVerifier = DiscordSDKManager.string(from: verifierString) ?? ""
            Discord_Free(verifierString.ptr)

            let state = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            var args = Discord_AuthorizationArgs(opaque: nil)
            Discord_AuthorizationArgs_Init(&args)
            defer { Discord_AuthorizationArgs_Drop(&args) }
            Discord_AuthorizationArgs_SetClientId(&args, applicationId)
            Discord_AuthorizationArgs_SetCodeChallenge(&args, &challenge)
            withDiscordString(DiscordSDKManager.presenceScopes) {
                Discord_AuthorizationArgs_SetScopes(&args, $0)
            }
            withMutableDiscordString(state) { stateString in
                Discord_AuthorizationArgs_SetState(&args, &stateString)
            }

            let box = DiscordAuthorizationCallbackBox { result in
                continuation.resume(with: result)
            }
            Discord_Client_Authorize(
                &client,
                &args,
                { result, code, redirectURI, userData in
                    guard let userData else { return }
                    let box = Unmanaged<DiscordAuthorizationCallbackBox>.fromOpaque(userData).takeUnretainedValue()
                    let isSuccessful = result.map { Discord_ClientResult_Successful($0) } ?? false
                    if isSuccessful {
                        let response = DiscordAuthorizationResponse(
                            code: DiscordSDKManager.string(from: code) ?? "",
                            redirectURI: DiscordSDKManager.string(from: redirectURI) ?? "",
                            codeVerifier: box.codeVerifier
                        )
                        DispatchQueue.main.async {
                            box.completion(.success(response))
                        }
                    } else {
                        let message = result.flatMap { DiscordSDKManager.resultErrorMessage($0) } ?? "Discord authorization failed."
                        DispatchQueue.main.async {
                            box.completion(.failure(.sdk(message)))
                        }
                    }
                    Discord_Free(redirectURI.ptr)
                    Discord_Free(code.ptr)
                },
                { pointer in
                    guard let pointer else { return }
                    Unmanaged<DiscordAuthorizationCallbackBox>.fromOpaque(pointer).release()
                },
                Unmanaged.passRetained(box.withCodeVerifier(codeVerifier)).toOpaque()
            )
        }
    }

    /// Exchanges an authorization code and verifier for an OAuth token bundle.
    ///
    /// - Parameters:
    ///   - code: Authorization code returned by Discord.
    ///   - codeVerifier: PKCE verifier created before authorization.
    ///   - redirectURI: Redirect URI returned with the authorization code.
    ///   - applicationId: Numeric Discord Developer Portal application ID used as the OAuth client ID.
    private func exchangeAuthorizationCode(
        _ code: String,
        codeVerifier: String,
        redirectURI: String,
        applicationId: UInt64
    ) async throws -> DiscordOAuthToken {
        guard !code.isEmpty, !codeVerifier.isEmpty, !redirectURI.isEmpty else {
            throw DiscordSDKError.sdk("Discord OAuth callback is missing code, verifier, or redirect URI.")
        }
        return try await withCheckedThrowingContinuation { continuation in
            withDiscordString(code) { codeString in
                withDiscordString(codeVerifier) { verifierString in
                    withDiscordString(redirectURI) { redirectString in
                        let box = DiscordTokenCallbackBox { result in
                            continuation.resume(with: result)
                        }
                        Discord_Client_GetToken(
                            &client,
                            applicationId,
                            codeString,
                            verifierString,
                            redirectString,
                            tokenExchangeCallback,
                            { pointer in
                                guard let pointer else { return }
                                Unmanaged<DiscordTokenCallbackBox>.fromOpaque(pointer).release()
                            },
                            Unmanaged.passRetained(box).toOpaque()
                        )
                    }
                }
            }
        }
    }

    /// Refreshes an expired Discord access token.
    ///
    /// - Parameters:
    ///   - refreshToken: Saved refresh token used to request a new access token.
    ///   - applicationId: Numeric Discord Developer Portal application ID used as the OAuth client ID.
    private func refreshToken(_ refreshToken: String, applicationId: UInt64) async throws -> DiscordOAuthToken {
        try await withCheckedThrowingContinuation { continuation in
            withDiscordString(refreshToken) { refreshString in
                let box = DiscordTokenCallbackBox { result in
                    continuation.resume(with: result)
                }
                Discord_Client_RefreshToken(
                    &client,
                    applicationId,
                    refreshString,
                    tokenExchangeCallback,
                    { pointer in
                        guard let pointer else { return }
                        Unmanaged<DiscordTokenCallbackBox>.fromOpaque(pointer).release()
                    },
                    Unmanaged.passRetained(box).toOpaque()
                )
            }
        }
    }

    /// Updates the native Discord SDK with a valid OAuth access token.
    ///
    /// - Parameter token: OAuth token bundle containing the access token and token type.
    private func updateSDKToken(_ token: DiscordOAuthToken) async throws {
        try await withCheckedThrowingContinuation { continuation in
            withDiscordString(token.accessToken) { accessTokenString in
                let box = DiscordVoidCallbackBox { result in
                    continuation.resume(with: result)
                }
                Discord_Client_UpdateToken(
                    &client,
                    token.tokenType.discordTokenType,
                    accessTokenString,
                    { result, userData in
                        guard let userData else { return }
                        let box = Unmanaged<DiscordVoidCallbackBox>.fromOpaque(userData).takeUnretainedValue()
                        let isSuccessful = result.map { Discord_ClientResult_Successful($0) } ?? false
                        let message = result.flatMap { DiscordSDKManager.resultErrorMessage($0) }
                        DispatchQueue.main.async {
                            if isSuccessful {
                                box.completion?(.success(()))
                            } else {
                                box.completion?(.failure(.sdk(message?.nilIfEmpty ?? "Discord token update failed.")))
                            }
                        }
                    },
                    { pointer in
                        guard let pointer else { return }
                        Unmanaged<DiscordVoidCallbackBox>.fromOpaque(pointer).release()
                    },
                    Unmanaged.passRetained(box).toOpaque()
                )
            }
        }
    }

    /// Fetches the authenticated user, retrying the local SDK cache before falling back to an API call.
    ///
    /// - Parameter token: OAuth token used when a direct SDK user lookup is not ready.
    private func fetchAuthenticatedUser(using token: DiscordOAuthToken) async throws -> DiscordUser {
        for attempt in 0..<6 {
            if let user = currentUserFromAuthenticatedClient() {
                return user
            }
            if attempt < 5 {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }

        let tokenUser = try await fetchCurrentUser(using: token)
        guard tokenUser.id != "0", tokenUser.username != "Discord User" else {
            throw DiscordSDKError.sdk("Discord 인증은 완료됐지만 사용자 정보를 아직 가져오지 못했습니다. 잠시 후 사용자 새로고침을 다시 시도하세요.")
        }
        return tokenUser
    }

    /// Fetches the current Discord user using an OAuth token.
    ///
    /// - Parameter token: OAuth token used to call the Discord current-user endpoint through the SDK.
    private func fetchCurrentUser(using token: DiscordOAuthToken) async throws -> DiscordUser {
        try await withCheckedThrowingContinuation { continuation in
            withDiscordString(token.accessToken) { tokenString in
                let box = DiscordFetchUserCallbackBox { result in
                    continuation.resume(with: result)
                }
                Discord_Client_FetchCurrentUser(
                    &client,
                    token.tokenType.discordTokenType,
                    tokenString,
                    { result, id, name, userData in
                        guard let userData else { return }
                        let box = Unmanaged<DiscordFetchUserCallbackBox>.fromOpaque(userData).takeUnretainedValue()
                        let isSuccessful = result.map { Discord_ClientResult_Successful($0) } ?? false
                        if isSuccessful {
                            let user = DiscordUser(
                                id: String(id),
                                username: DiscordSDKManager.string(from: name) ?? "Discord User",
                                discriminator: nil,
                                avatar: nil
                            )
                            DispatchQueue.main.async {
                                box.completion(.success(user))
                            }
                        } else {
                            let message = result.flatMap { DiscordSDKManager.resultErrorMessage($0) } ?? "Failed to fetch Discord user."
                            DispatchQueue.main.async {
                                box.completion(.failure(.sdk(message)))
                            }
                        }
                        Discord_Free(name.ptr)
                    },
                    { pointer in
                        guard let pointer else { return }
                        Unmanaged<DiscordFetchUserCallbackBox>.fromOpaque(pointer).release()
                    },
                    Unmanaged.passRetained(box).toOpaque()
                )
            }
        }
    }

    /// Reads the current user directly from the authenticated native client.
    private func currentUserFromAuthenticatedClient() -> DiscordUser? {
        guard isClientInitialized else { return nil }

        var userHandle = Discord_UserHandle(opaque: nil)
        let hasV2User = Discord_Client_GetCurrentUserV2(&client, &userHandle)
        if !hasV2User || userHandle.opaque == nil {
            Discord_Client_GetCurrentUser(&client, &userHandle)
        }
        guard userHandle.opaque != nil else { return nil }
        defer { Discord_UserHandle_Drop(&userHandle) }

        let id = Discord_UserHandle_Id(&userHandle)
        guard id != 0 else { return nil }

        let displayName = requiredUserString { Discord_UserHandle_DisplayName(&userHandle, $0) }
        let username = requiredUserString { Discord_UserHandle_Username(&userHandle, $0) }
        let globalName = optionalUserString { Discord_UserHandle_GlobalName(&userHandle, $0) }
        let avatar = optionalUserString { Discord_UserHandle_Avatar(&userHandle, $0) }
        let resolvedName = displayName.nilIfEmpty ?? globalName?.nilIfEmpty ?? username.nilIfEmpty ?? "Discord User"

        return DiscordUser(
            id: String(id),
            username: resolvedName,
            discriminator: nil,
            avatar: avatar
        )
    }

    /// Reads the Rich Presence activity currently attached to the authenticated user.
    private func currentPresenceActivityFromAuthenticatedClient() -> DiscordActivity? {
        guard isClientInitialized else { return nil }

        var userHandle = Discord_UserHandle(opaque: nil)
        let hasV2User = Discord_Client_GetCurrentUserV2(&client, &userHandle)
        if !hasV2User || userHandle.opaque == nil {
            Discord_Client_GetCurrentUser(&client, &userHandle)
        }
        guard userHandle.opaque != nil else { return nil }
        defer { Discord_UserHandle_Drop(&userHandle) }

        var nativeActivity = Discord_Activity(opaque: nil)
        guard Discord_UserHandle_GameActivity(&userHandle, &nativeActivity) else { return nil }
        defer { Discord_Activity_Drop(&nativeActivity) }

        return DiscordActivity(nativeActivity: &nativeActivity)
    }

    /// Reads a required Discord string field and returns an empty string when unavailable.
    ///
    /// - Parameter getter: Native Discord getter that writes into a `Discord_String` pointer.
    private func requiredUserString(_ getter: (UnsafeMutablePointer<Discord_String>?) -> Void) -> String {
        var string = Discord_String(ptr: nil, size: 0)
        getter(&string)
        defer { Discord_Free(string.ptr) }
        return DiscordSDKManager.string(from: string) ?? ""
    }

    /// Reads an optional Discord string field.
    ///
    /// - Parameter getter: Native Discord getter that returns whether it wrote a `Discord_String`.
    private func optionalUserString(_ getter: (UnsafeMutablePointer<Discord_String>?) -> Bool) -> String? {
        var string = Discord_String(ptr: nil, size: 0)
        guard getter(&string) else { return nil }
        defer { Discord_Free(string.ptr) }
        return DiscordSDKManager.string(from: string)
    }

    /// Revokes an access token through Discord and reports the SDK result.
    ///
    /// - Parameters:
    ///   - token: Access token to revoke.
    ///   - applicationId: Numeric Discord Developer Portal application ID used as the OAuth client ID.
    ///   - completion: Completion called after Discord accepts or rejects token revocation.
    private func revokeToken(_ token: String, applicationId: UInt64, completion: ((Result<Void, DiscordSDKError>) -> Void)? = nil) {
        withDiscordString(token) { tokenString in
            let box = DiscordVoidCallbackBox(completion: completion)
            Discord_Client_RevokeToken(
                &client,
                applicationId,
                tokenString,
                { result, userData in
                    guard let userData else { return }
                    let box = Unmanaged<DiscordVoidCallbackBox>.fromOpaque(userData).takeUnretainedValue()
                    let isSuccessful = result.map { Discord_ClientResult_Successful($0) } ?? false
                    let message = result.flatMap { DiscordSDKManager.resultErrorMessage($0) }
                    DispatchQueue.main.async {
                        if isSuccessful {
                            box.completion?(.success(()))
                        } else {
                            box.completion?(.failure(.sdk(message?.nilIfEmpty ?? "Discord token revoke failed.")))
                        }
                    }
                },
                { pointer in
                    guard let pointer else { return }
                    Unmanaged<DiscordVoidCallbackBox>.fromOpaque(pointer).release()
                },
                Unmanaged.passRetained(box).toOpaque()
            )
        }
    }

    /// Refreshes the saved token when Discord reports that the current token is expiring.
    private func refreshStoredTokenIfPossible() async {
        guard let savedToken = tokenStore.load(),
              let applicationId = normalizedApplicationId,
              !savedToken.refreshToken.isEmpty else {
            authorizationStatus = .unauthorized
            dashboardStatus = .unauthorized
            return
        }

        do {
            let refreshed = try await refreshToken(savedToken.refreshToken, applicationId: applicationId)
            tokenStore.save(refreshed)
            try await updateSDKToken(refreshed)
            let user = try await fetchAuthenticatedUser(using: refreshed)
            currentUser = user
            authorizationStatus = .authorized
            dashboardStatus = .ready
            lastErrorMessage = nil
        } catch {
            tokenStore.delete()
            authorizationStatus = .unauthorized
            dashboardStatus = .failed
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Converts a Discord SDK string buffer to a Swift string without taking ownership.
    ///
    /// - Parameter discordString: Native Discord string buffer to decode as UTF-8.
    fileprivate static func string(from discordString: Discord_String) -> String? {
        guard let pointer = discordString.ptr, discordString.size > 0 else { return nil }
        let buffer = UnsafeBufferPointer(start: pointer, count: discordString.size)
        return String(bytes: buffer, encoding: .utf8)
    }

    /// Converts a Swift date to the millisecond timestamp expected by Discord activity APIs.
    ///
    /// - Parameter date: Swift date to convert to a Discord timestamp.
    fileprivate static func discordTimestamp(from date: Date) -> UInt64 {
        UInt64(max(0, (date.timeIntervalSince1970 * 1_000).rounded()))
    }

    /// Extracts an error message from a native Discord client result.
    ///
    /// - Parameter result: Native Discord client result pointer returned by an SDK callback.
    fileprivate static func resultErrorMessage(_ result: UnsafeMutablePointer<Discord_ClientResult>) -> String? {
        var error = Discord_String(ptr: nil, size: 0)
        Discord_ClientResult_Error(result, &error)
        defer { Discord_Free(error.ptr) }
        return string(from: error)
    }

    /// OAuth scopes required for identity and Rich Presence updates.
    fileprivate static let presenceScopes = "openid identify sdk.social_layer_presence"

    /// Provides a temporary immutable Discord string backed by UTF-8 bytes.
    ///
    /// - Parameters:
    ///   - value: Swift string to expose as a temporary `Discord_String`.
    ///   - body: Closure that receives the temporary Discord string while its backing bytes are valid.
    private func withDiscordString<R>(_ value: String, _ body: (Discord_String) -> R) -> R {
        var bytes = Array(value.utf8)
        return bytes.withUnsafeMutableBufferPointer { buffer in
            body(Discord_String(ptr: buffer.baseAddress, size: buffer.count))
        }
    }

    /// Provides a temporary mutable Discord string backed by UTF-8 bytes.
    ///
    /// - Parameters:
    ///   - value: Swift string to expose as a temporary mutable `Discord_String`.
    ///   - body: Closure that receives the temporary Discord string while its backing bytes are valid.
    private func withMutableDiscordString<R>(_ value: String, _ body: (inout Discord_String) -> R) -> R {
        var bytes = Array(value.utf8)
        return bytes.withUnsafeMutableBufferPointer { buffer in
            var string = Discord_String(ptr: buffer.baseAddress, size: buffer.count)
            return body(&string)
        }
    }

    /// Applies an optional Swift string to a native Discord object and reports whether it was set.
    ///
    /// - Parameters:
    ///   - value: Optional Swift string to trim and pass to the native setter.
    ///   - target: Native Discord object that should receive the string.
    ///   - setter: Native Discord setter that accepts the target pointer and a string pointer.
    @discardableResult
    private func setOptionalString<T>(
        _ value: String?,
        on target: inout T,
        setter: (UnsafeMutablePointer<T>?, UnsafeMutablePointer<Discord_String>?) -> Void
    ) -> Bool {
        guard let value = value?.nilIfEmpty else { return false }
        withDiscordString(value) { discordString in
            var mutableString = discordString
            setter(&target, &mutableString)
        }
        return true
    }

    /// Updates dashboard state in response to native Discord connection status callbacks.
    ///
    /// - Parameters:
    ///   - status: Native Discord connection status.
    ///   - error: Native Discord connection error value.
    ///   - detail: Additional native Discord error detail code.
    fileprivate func handleStatusChanged(status: Discord_Client_Status, error: Discord_Client_Error, detail: Int32) {
        switch status {
        case Discord_Client_Status_Ready:
            dashboardStatus = .ready
            authorizationStatus = Discord_Client_IsAuthenticated(&client) ? .authorized : .unauthorized
            lastErrorMessage = nil
        case Discord_Client_Status_Connected:
            dashboardStatus = .connecting
        case Discord_Client_Status_Connecting, Discord_Client_Status_Reconnecting, Discord_Client_Status_HttpWait:
            dashboardStatus = .connecting
        case Discord_Client_Status_Disconnected, Discord_Client_Status_Disconnecting:
            dashboardStatus = .configured
        default:
            dashboardStatus = .configured
        }

        if error != Discord_Client_Error_None {
            lastErrorMessage = "Discord SDK connection error: \(error.rawValue) (\(detail))"
            dashboardStatus = .failed
        }
    }
    #endif
}

/// Discord user identity returned by the SDK.
struct DiscordUser: Sendable, Equatable, Hashable {
    /// Discord snowflake user ID.
    var id: String

    /// Display name or username reported by Discord.
    var username: String

    /// Legacy discriminator, when Discord provides one.
    var discriminator: String?

    /// Avatar hash or URL string, when available.
    var avatar: String?
}

/// OAuth token bundle used to restore Discord authorization.
struct DiscordOAuthToken: Codable, Sendable, Equatable {
    /// Discord token kind used when sending tokens back to the SDK.
    enum TokenType: String, Codable, Sendable, Equatable {
        /// User token returned by Discord authorization.
        case user

        /// Bearer token returned by Discord authorization.
        case bearer
    }

    /// Access token used by Discord API and SDK calls.
    var accessToken: String

    /// Refresh token used to renew expired access tokens.
    var refreshToken: String

    /// Token type reported by Discord.
    var tokenType: TokenType

    /// Date when the access token expires.
    var expiresAt: Date

    /// OAuth scopes granted for this token.
    var scopes: String

    /// Whether the access token has enough remaining lifetime for immediate use.
    var isAccessTokenUsable: Bool {
        !accessToken.isEmpty && expiresAt.timeIntervalSinceNow > 60
    }
}

/// Authorization-code response plus PKCE verifier needed for token exchange.
private struct DiscordAuthorizationResponse: Sendable, Equatable {
    /// Authorization code returned by Discord.
    var code: String

    /// Redirect URI returned by Discord alongside the authorization code.
    var redirectURI: String

    /// PKCE verifier paired with the authorization request.
    var codeVerifier: String
}

/// Rich Presence activity model used before converting values to Discord SDK types.
struct DiscordActivity: Sendable, Equatable {
    /// Discord Rich Presence activity category.
    enum ActivityType: Int, CaseIterable, Identifiable, Sendable {
        /// Shows the activity as "Playing".
        case playing = 0

        /// Shows the activity as "Streaming".
        case streaming = 1

        /// Shows the activity as "Listening".
        case listening = 2

        /// Shows the activity as "Watching".
        case watching = 3

        /// Shows the activity as "Competing".
        case competing = 5

        /// Stable identifier used by SwiftUI pickers.
        var id: Int { rawValue }

        /// Human-readable activity type label.
        var displayName: String {
            switch self {
            case .playing: return "Playing"
            case .streaming: return "Streaming"
            case .listening: return "Listening"
            case .watching: return "Watching"
            case .competing: return "Competing"
            }
        }
    }

    /// Discord Developer Portal asset keys and tooltip labels.
    struct Assets: Sendable, Equatable {
        /// Discord Developer Portal key for the large Rich Presence image.
        var largeImage: String?

        /// Tooltip text for the large Rich Presence image.
        var largeText: String?

        /// Discord Developer Portal key for the small Rich Presence image.
        var smallImage: String?

        /// Tooltip text for the small Rich Presence image.
        var smallText: String?
    }

    /// Optional start and end times displayed by Discord.
    struct Timestamps: Sendable, Equatable {
        /// Start time used for elapsed time displays.
        var start: Date?

        /// End time used for remaining time displays.
        var end: Date?
    }

    /// Party metadata displayed as current and maximum size.
    struct Party: Sendable, Equatable {
        /// Stable party identifier for Discord party metadata.
        var id: String?

        /// Current party size.
        var currentSize: Int?

        /// Maximum party size.
        var maxSize: Int?
    }

    /// Activity title shown as the primary Rich Presence label.
    var name: String?

    /// Short status line, usually the current mode or context.
    var state: String?

    /// Longer status line, usually the item, track, or screen name.
    var details: String?

    /// Optional Rich Presence image assets.
    var assets = Assets()

    /// Optional elapsed or remaining time values.
    var timestamps = Timestamps()

    /// Optional party size metadata.
    var party = Party()

    /// Discord activity category.
    var type: ActivityType = .playing
}

/// Defines which app-owned Presence sources should be periodically reasserted.
enum PresencePriorityPolicy {
    nonisolated static func shouldPeriodicallyReassert(_ payload: AppliedPresencePayload) -> Bool {
        switch payload.source {
        case .manual, .schedule:
            return true
        case .program, .appleMusic, .xcode:
            return false
        }
    }
}

/// Periodically reapplies the selected presence so it stays ahead of lower-priority updates.
@MainActor
final class PresencePriorityController {
    /// Shared priority controller used by presence features.
    static let shared = PresencePriorityController()

    /// Background task that periodically checks whether presence should be reapplied.
    private var enforcementTask: Task<Void, Never>?

    /// Reentrancy guard for priority enforcement.
    private var isReapplying = false

    /// Prevents external construction so all callers share one priority controller.
    private init() {}

    /// Starts periodic priority enforcement unless UI tests are running.
    func start() {
        guard enforcementTask == nil, !AutomationLaunchOptions.isUITesting else {
            Log.d(
                "Skipped starting priority controller. alreadyStarted=\(enforcementTask != nil) uiTesting=\(AutomationLaunchOptions.isUITesting)",
                category: "PresencePriority"
            )
            return
        }
        Log.d("Starting priority controller", category: "PresencePriority")
        enforcementTask = Task { [weak self] in
            guard let self else { return }
            await enforceAppliedPresenceIfNeeded()
            while !Task.isCancelled {
                let intervalSeconds = await ConfigUtility.shared.presencePriorityReapplyIntervalSeconds()
                Log.d("Sleeping before next priority reassertion intervalSeconds=\(intervalSeconds)", category: "PresencePriority")
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds) * 1_000_000_000)
                await enforceAppliedPresenceIfNeeded()
            }
        }
    }

    /// Stops periodic priority enforcement.
    func stop() {
        Log.d("Stopping priority controller", category: "PresencePriority")
        enforcementTask?.cancel()
        enforcementTask = nil
    }

    /// Reapplies the last persistent app-owned Presence without depending on external Presence detection.
    func enforceAppliedPresenceIfNeeded() async {
        guard !isReapplying else {
            Log.d("Skipped enforcement because a reapply is already in progress", category: "PresencePriority")
            return
        }
        let isPriorityEnabled = await ConfigUtility.shared.isPresencePriorityEnabled()
        guard isPriorityEnabled else {
            Log.d("Skipped enforcement because Presence priority is disabled", category: "PresencePriority")
            return
        }
        guard let appliedPresence = await ConfigUtility.shared.currentAppliedPresence() else {
            Log.d("Skipped enforcement because no applied Presence is stored", category: "PresencePriority")
            return
        }
        guard PresencePriorityPolicy.shouldPeriodicallyReassert(appliedPresence) else {
            Log.d(
                "Skipped periodic reassertion for transient source=\(appliedPresence.source.rawValue)",
                category: "PresencePriority"
            )
            return
        }

        do {
            isReapplying = true
            defer { isReapplying = false }

            Log.d("Periodically reasserting stored Presence target: \(appliedPresence.debugSummary)", category: "PresencePriority")
            try await DiscordSDKManager.shared.updateActivity(appliedPresence)
            Log.d("Finished periodic Presence reassertion", category: "PresencePriority")
        } catch {
            Log.d("Failed to enforce applied Presence priority: \(error)", category: "PresencePriority")
        }
    }
}

/// Errors surfaced by the Discord SDK integration layer.
enum DiscordSDKError: Error, LocalizedError, Sendable, Equatable {
    /// The configured Discord application ID is missing, still a placeholder, or malformed.
    case invalidApplicationID(String)

    /// The SDK has not been configured with a valid application ID.
    case notConfigured

    /// No valid Discord authorization is available for the current application ID.
    case unauthorized

    /// The Discord Social SDK module is not linked into the current build.
    case unsupportedPlatform

    /// Native Discord SDK call failed.
    case sdk(String)

    /// Localized error text suitable for user-facing surfaces.
    var errorDescription: String? {
        switch self {
        case .invalidApplicationID(let message):
            return "Discord APPLICATION_ID 설정이 잘못되었습니다. \(message)"
        case .notConfigured:
            return "Discord SDK가 아직 설정되지 않았습니다."
        case .unauthorized:
            return "Discord 인증이 완료되지 않았습니다."
        case .unsupportedPlatform:
            return "현재 빌드에서 Discord Social SDK를 찾을 수 없습니다."
        case .sdk(let message):
            return message
        }
    }
}

/// Compact debug summaries for Presence priority diagnostics.
private extension AppliedPresencePayload {
    var debugSummary: String {
        [
            "source=\(source.rawValue)",
            "type=\(activityType.rawValue)",
            "name=\(debugValue(name))",
            "details=\(debugValue(details))",
            "state=\(debugValue(state))",
            "large=\(debugValue(largeImageKey))",
            "small=\(debugValue(smallImageKey))",
            "start=\(start.map { String(Int($0.timeIntervalSince1970)) } ?? "nil")",
            "end=\(end.map { String(Int($0.timeIntervalSince1970)) } ?? "nil")",
            "party=\(debugValue(partyID))/\(partyCurrent.map(String.init) ?? "nil")/\(partyMax.map(String.init) ?? "nil")"
        ].joined(separator: " ")
    }

    private func debugValue(_ value: String?) -> String {
        value?.nilIfEmpty ?? "nil"
    }
}

private extension DiscordActivity {
    var debugSummary: String {
        [
            "type=\(type.displayName)",
            "name=\(debugValue(name))",
            "details=\(debugValue(details))",
            "state=\(debugValue(state))",
            "large=\(debugValue(assets.largeImage))",
            "small=\(debugValue(assets.smallImage))",
            "start=\(timestamps.start.map { String(Int($0.timeIntervalSince1970)) } ?? "nil")",
            "end=\(timestamps.end.map { String(Int($0.timeIntervalSince1970)) } ?? "nil")",
            "party=\(debugValue(party.id))/\(party.currentSize.map(String.init) ?? "nil")/\(party.maxSize.map(String.init) ?? "nil")"
        ].joined(separator: " ")
    }

    private func debugValue(_ value: String?) -> String {
        value?.nilIfEmpty ?? "nil"
    }
}

#if canImport(discord_partner_sdk)
/// Retains state for a Discord authorization callback until the C callback releases it.
private final class DiscordAuthorizationCallbackBox {
    /// PKCE verifier paired with the authorization request.
    var codeVerifier = ""

    /// Completion called with the authorization response or SDK error.
    let completion: (Result<DiscordAuthorizationResponse, DiscordSDKError>) -> Void

    /// Creates a callback box with a Swift completion closure.
    ///
    /// - Parameter completion: Completion called with the authorization response or SDK error.
    init(completion: @escaping (Result<DiscordAuthorizationResponse, DiscordSDKError>) -> Void) {
        self.completion = completion
    }

    /// Stores the PKCE verifier and returns this box for fluent setup.
    ///
    /// - Parameter codeVerifier: PKCE verifier created for the authorization request.
    func withCodeVerifier(_ codeVerifier: String) -> DiscordAuthorizationCallbackBox {
        self.codeVerifier = codeVerifier
        return self
    }
}

/// Retains a token exchange completion until the Discord C callback releases it.
private final class DiscordTokenCallbackBox {
    /// Completion called with OAuth tokens or an SDK error.
    let completion: (Result<DiscordOAuthToken, DiscordSDKError>) -> Void

    /// Creates a token callback box with a Swift completion closure.
    ///
    /// - Parameter completion: Completion called with OAuth tokens or an SDK error.
    init(completion: @escaping (Result<DiscordOAuthToken, DiscordSDKError>) -> Void) {
        self.completion = completion
    }
}

/// Retains a current-user completion until the Discord C callback releases it.
private final class DiscordFetchUserCallbackBox {
    /// Completion called with the fetched Discord user or an SDK error.
    let completion: (Result<DiscordUser, DiscordSDKError>) -> Void

    /// Creates a user callback box with a Swift completion closure.
    ///
    /// - Parameter completion: Completion called with the fetched Discord user or SDK error.
    init(completion: @escaping (Result<DiscordUser, DiscordSDKError>) -> Void) {
        self.completion = completion
    }
}

/// Retains a void completion until the Discord C callback releases it.
private final class DiscordVoidCallbackBox {
    /// Completion called with success or an SDK error.
    let completion: ((Result<Void, DiscordSDKError>) -> Void)?

    /// Creates a void callback box with an optional Swift completion closure.
    ///
    /// - Parameter completion: Completion called with success or an SDK error.
    init(completion: ((Result<Void, DiscordSDKError>) -> Void)?) {
        self.completion = completion
    }
}

/// Shared token-exchange callback used by authorization-code and refresh-token flows.
private let tokenExchangeCallback: Discord_Client_TokenExchangeCallback = { result, accessToken, refreshToken, tokenType, expiresIn, scopes, userData in
    guard let userData else { return }
    let box = Unmanaged<DiscordTokenCallbackBox>.fromOpaque(userData).takeUnretainedValue()
    let isSuccessful = result.map { Discord_ClientResult_Successful($0) } ?? false
    if isSuccessful {
        let token = DiscordOAuthToken(
            accessToken: DiscordSDKManager.string(from: accessToken) ?? "",
            refreshToken: DiscordSDKManager.string(from: refreshToken) ?? "",
            tokenType: DiscordOAuthToken.TokenType(discordTokenType: tokenType),
            expiresAt: Date().addingTimeInterval(TimeInterval(max(0, expiresIn))),
            scopes: DiscordSDKManager.string(from: scopes) ?? ""
        )
        DispatchQueue.main.async {
            box.completion(.success(token))
        }
    } else {
        let message = result.flatMap { DiscordSDKManager.resultErrorMessage($0) } ?? "Discord token exchange failed."
        DispatchQueue.main.async {
            box.completion(.failure(.sdk(message)))
        }
    }
    Discord_Free(scopes.ptr)
    Discord_Free(refreshToken.ptr)
    Discord_Free(accessToken.ptr)
}

/// Native Discord Social SDK conversion helpers for activity types.
private extension DiscordActivity.ActivityType {
    /// Native Discord Social SDK activity type matching this app model value.
    var socialSDKActivityType: Discord_ActivityTypes {
        switch self {
        case .playing:
            return Discord_ActivityTypes_Playing
        case .streaming:
            return Discord_ActivityTypes_Streaming
        case .listening:
            return Discord_ActivityTypes_Listening
        case .watching:
            return Discord_ActivityTypes_Watching
        case .competing:
            return Discord_ActivityTypes_Competing
        }
    }

    /// Creates an app activity type from a native Discord Social SDK value.
    ///
    /// - Parameter socialSDKActivityType: Native Discord activity type to convert.
    init?(socialSDKActivityType: Discord_ActivityTypes) {
        switch socialSDKActivityType {
        case Discord_ActivityTypes_Playing:
            self = .playing
        case Discord_ActivityTypes_Streaming:
            self = .streaming
        case Discord_ActivityTypes_Listening:
            self = .listening
        case Discord_ActivityTypes_Watching:
            self = .watching
        case Discord_ActivityTypes_Competing:
            self = .competing
        default:
            return nil
        }
    }
}

/// Native Discord Social SDK conversion helpers for activities.
private extension DiscordActivity {
    /// Creates a Swift Rich Presence activity from a native Discord activity handle.
    ///
    /// - Parameter nativeActivity: Native Discord activity handle to read before it is dropped.
    init(nativeActivity: UnsafeMutablePointer<Discord_Activity>) {
        var activity = DiscordActivity()
        activity.name = Self.requiredString { Discord_Activity_Name(nativeActivity, $0) }
        activity.state = Self.optionalString { Discord_Activity_State(nativeActivity, $0) }
        activity.details = Self.optionalString { Discord_Activity_Details(nativeActivity, $0) }
        activity.type = ActivityType(socialSDKActivityType: Discord_Activity_Type(nativeActivity)) ?? .playing

        var nativeAssets = Discord_ActivityAssets(opaque: nil)
        if Discord_Activity_Assets(nativeActivity, &nativeAssets) {
            defer { Discord_ActivityAssets_Drop(&nativeAssets) }
            activity.assets.largeImage = Self.optionalString { Discord_ActivityAssets_LargeImage(&nativeAssets, $0) }
            activity.assets.largeText = Self.optionalString { Discord_ActivityAssets_LargeText(&nativeAssets, $0) }
            activity.assets.smallImage = Self.optionalString { Discord_ActivityAssets_SmallImage(&nativeAssets, $0) }
            activity.assets.smallText = Self.optionalString { Discord_ActivityAssets_SmallText(&nativeAssets, $0) }
        }

        var nativeTimestamps = Discord_ActivityTimestamps(opaque: nil)
        if Discord_Activity_Timestamps(nativeActivity, &nativeTimestamps) {
            defer { Discord_ActivityTimestamps_Drop(&nativeTimestamps) }
            let start = Discord_ActivityTimestamps_Start(&nativeTimestamps)
            let end = Discord_ActivityTimestamps_End(&nativeTimestamps)
            activity.timestamps.start = Self.date(fromDiscordTimestamp: start)
            activity.timestamps.end = Self.date(fromDiscordTimestamp: end)
        }

        var nativeParty = Discord_ActivityParty(opaque: nil)
        if Discord_Activity_Party(nativeActivity, &nativeParty) {
            defer { Discord_ActivityParty_Drop(&nativeParty) }
            activity.party.id = Self.requiredString { Discord_ActivityParty_Id(&nativeParty, $0) }
            let currentSize = Int(Discord_ActivityParty_CurrentSize(&nativeParty))
            let maxSize = Int(Discord_ActivityParty_MaxSize(&nativeParty))
            activity.party.currentSize = currentSize > 0 ? currentSize : nil
            activity.party.maxSize = maxSize > 0 ? maxSize : nil
        }

        self = activity
    }

    /// Reads a required native Discord string and normalizes blank values to nil.
    ///
    /// - Parameter getter: Native Discord getter that writes into a `Discord_String` pointer.
    private static func requiredString(_ getter: (UnsafeMutablePointer<Discord_String>?) -> Void) -> String? {
        var string = Discord_String(ptr: nil, size: 0)
        getter(&string)
        defer { Discord_Free(string.ptr) }
        return DiscordSDKManager.string(from: string)?.nilIfEmpty
    }

    /// Reads an optional native Discord string and normalizes blank values to nil.
    ///
    /// - Parameter getter: Native Discord getter that returns whether it wrote a `Discord_String`.
    private static func optionalString(_ getter: (UnsafeMutablePointer<Discord_String>?) -> Bool) -> String? {
        var string = Discord_String(ptr: nil, size: 0)
        guard getter(&string) else { return nil }
        defer { Discord_Free(string.ptr) }
        return DiscordSDKManager.string(from: string)?.nilIfEmpty
    }

    /// Converts Discord activity timestamps from seconds or milliseconds into `Date`.
    ///
    /// - Parameter value: Discord timestamp in seconds or milliseconds since the Unix epoch.
    private static func date(fromDiscordTimestamp value: UInt64) -> Date? {
        guard value > 0 else { return nil }
        let seconds: TimeInterval
        if value < 10_000_000_000 {
            seconds = TimeInterval(value)
        } else {
            seconds = TimeInterval(value) / 1_000
        }
        return Date(timeIntervalSince1970: seconds)
    }
}

/// Native Discord Social SDK conversion helpers for OAuth token types.
private extension DiscordOAuthToken.TokenType {
    /// Creates an app token type from a native Discord authorization token type.
    ///
    /// - Parameter discordTokenType: Native Discord authorization token type to convert.
    init(discordTokenType: Discord_AuthorizationTokenType) {
        switch discordTokenType {
        case Discord_AuthorizationTokenType_User:
            self = .user
        case Discord_AuthorizationTokenType_Bearer:
            self = .bearer
        default:
            self = .bearer
        }
    }

    /// Native Discord authorization token type matching this app model value.
    var discordTokenType: Discord_AuthorizationTokenType {
        switch self {
        case .user:
            return Discord_AuthorizationTokenType_User
        case .bearer:
            return Discord_AuthorizationTokenType_Bearer
        }
    }
}
#endif

/// Keychain storage for Discord OAuth tokens.
private final class DiscordTokenStore {
    /// Keychain service name for Discord OAuth token data.
    private let service = "CraftPresence.DiscordOAuth"

    /// Keychain account name for the single stored Discord OAuth token.
    private let account = "DiscordOAuthToken"

    /// JSON encoder used before saving token data to Keychain.
    private let encoder = JSONEncoder()

    /// JSON decoder used after loading token data from Keychain.
    private let decoder = JSONDecoder()

    /// Loads the stored Discord OAuth token from Keychain.
    func load() -> DiscordOAuthToken? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return try? decoder.decode(DiscordOAuthToken.self, from: data)
    }

    /// Saves a Discord OAuth token to Keychain, replacing any previous token.
    ///
    /// - Parameter token: OAuth token bundle to encode and store.
    func save(_ token: DiscordOAuthToken) {
        guard let data = try? encoder.encode(token) else { return }
        delete()

        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    /// Deletes the stored Discord OAuth token from Keychain.
    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    /// Base Keychain query shared by load, save, and delete operations.
    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

/// String normalization helpers used by Discord payload builders.
private extension String {
    /// Returns the trimmed string, or nil when the value contains only whitespace.
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
