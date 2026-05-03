import Foundation
import Combine
import Security
#if canImport(discord_partner_sdk)
import discord_partner_sdk
#endif

enum DiscordAppConfig {
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

@MainActor
final class DiscordSDKManager: ObservableObject {
    static let shared = DiscordSDKManager()

    enum AuthorizationStatus: Sendable, Equatable {
        case authorized
        case unauthorized
        case unknown
    }

    enum DashboardStatus: Sendable, Equatable {
        case notConfigured
        case configured
        case authorizing
        case connecting
        case ready
        case unauthorized
        case failed

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

    @Published private(set) var authorizationStatus: AuthorizationStatus = .unknown
    @Published private(set) var currentUser: DiscordUser?
    @Published private(set) var dashboardStatus: DashboardStatus = .notConfigured
    @Published private(set) var lastErrorMessage: String?

    private var configuredApplicationId: String?
    private let tokenStore = DiscordTokenStore()
    #if canImport(discord_partner_sdk)
    private var client = Discord_Client(opaque: nil)
    private var isClientInitialized = false
    private var callbackPumpTask: Task<Void, Never>?
    #endif

    private init() {}

    deinit {
        #if canImport(discord_partner_sdk)
        callbackPumpTask?.cancel()
        if isClientInitialized {
            Discord_Client_Disconnect(&client)
            Discord_Client_Drop(&client)
        }
        #endif
    }

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

    func authorizeIfNeeded(completion: ((Result<DiscordUser, DiscordSDKError>) -> Void)? = nil) {
        authorizeIfNeeded(allowInteractiveAuthorization: true, completion: completion)
    }

    func restoreAuthorizationIfPossible(completion: ((Result<DiscordUser, DiscordSDKError>) -> Void)? = nil) {
        authorizeIfNeeded(allowInteractiveAuthorization: false, completion: completion)
    }

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

    func logout(completion: ((Result<Void, DiscordSDKError>) -> Void)? = nil) {
        #if canImport(discord_partner_sdk)
        let savedToken = tokenStore.load()
        tokenStore.delete()
        if let applicationId = normalizedApplicationId,
           let token = savedToken?.accessToken,
           !token.isEmpty,
           isClientInitialized {
            revokeToken(token, applicationId: applicationId) { [weak self] result in
                self?.authorizationStatus = .unauthorized
                self?.currentUser = nil
                self?.dashboardStatus = self?.configuredApplicationId == nil ? .notConfigured : .unauthorized
                self?.lastErrorMessage = nil
                completion?(result)
            }
            return
        }
        #else
        tokenStore.delete()
        #endif
        authorizationStatus = .unauthorized
        currentUser = nil
        dashboardStatus = configuredApplicationId == nil ? .notConfigured : .unauthorized
        lastErrorMessage = nil
        completion?(.success(()))
    }

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
                let message: String? = result.flatMap { resultPointer in
                    var error = Discord_String(ptr: nil, size: 0)
                    Discord_ClientResult_Error(resultPointer, &error)
                    return DiscordSDKManager.string(from: error)
                }

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

    func authorizeIfNeeded() async throws -> DiscordUser {
        try await withCheckedThrowingContinuation { continuation in
            authorizeIfNeeded { result in
                continuation.resume(with: result)
            }
        }
    }

    func restoreAuthorizationIfPossible() async throws -> DiscordUser {
        try await withCheckedThrowingContinuation { continuation in
            restoreAuthorizationIfPossible { result in
                continuation.resume(with: result)
            }
        }
    }

    func currentUser() async throws -> DiscordUser {
        try await withCheckedThrowingContinuation { continuation in
            fetchCurrentUser { result in
                continuation.resume(with: result)
            }
        }
    }

    func currentPresenceActivity() async throws -> DiscordActivity? {
        if authorizationStatus != .authorized {
            _ = try await restoreAuthorizationIfPossible()
        }
        #if canImport(discord_partner_sdk)
        return currentPresenceActivityFromAuthenticatedClient()
        #else
        throw DiscordSDKError.unsupportedPlatform
        #endif
    }

    func logout() async throws {
        try await withCheckedThrowingContinuation { continuation in
            logout { result in
                continuation.resume(with: result)
            }
        }
    }

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

    func clearActivity() async throws {
        try await withCheckedThrowingContinuation { continuation in
            clearActivity { result in
                continuation.resume(with: result)
            }
        }
    }

    #if canImport(discord_partner_sdk)
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

    private func resetSocialSDK() {
        stopCallbackPump()
        if isClientInitialized {
            Discord_Client_Disconnect(&client)
            Discord_Client_Drop(&client)
            client = Discord_Client(opaque: nil)
            isClientInitialized = false
        }
    }

    private func startCallbackPump() {
        stopCallbackPump()
        callbackPumpTask = Task { @MainActor [weak self] in
            while let self, self.isClientInitialized, !Task.isCancelled {
                Discord_RunCallbacks()
                try? await Task.sleep(nanoseconds: 33_000_000)
            }
        }
    }

    private func stopCallbackPump() {
        callbackPumpTask?.cancel()
        callbackPumpTask = nil
    }

    private var normalizedApplicationId: UInt64? {
        guard let configuredApplicationId,
              let applicationId = UInt64(configuredApplicationId) else {
            return nil
        }
        return applicationId
    }

    private func runOAuthAuthorization(applicationId: UInt64) async throws -> DiscordOAuthToken {
        let authorization = try await requestAuthorizationCode(applicationId: applicationId)
        return try await exchangeAuthorizationCode(
            authorization.code,
            codeVerifier: authorization.codeVerifier,
            redirectURI: authorization.redirectURI,
            applicationId: applicationId
        )
    }

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

    private func requiredUserString(_ getter: (UnsafeMutablePointer<Discord_String>?) -> Void) -> String {
        var string = Discord_String(ptr: nil, size: 0)
        getter(&string)
        defer { Discord_Free(string.ptr) }
        return DiscordSDKManager.string(from: string) ?? ""
    }

    private func optionalUserString(_ getter: (UnsafeMutablePointer<Discord_String>?) -> Bool) -> String? {
        var string = Discord_String(ptr: nil, size: 0)
        guard getter(&string) else { return nil }
        defer { Discord_Free(string.ptr) }
        return DiscordSDKManager.string(from: string)
    }

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

    fileprivate static func string(from discordString: Discord_String) -> String? {
        guard let pointer = discordString.ptr, discordString.size > 0 else { return nil }
        let buffer = UnsafeBufferPointer(start: pointer, count: discordString.size)
        return String(bytes: buffer, encoding: .utf8)
    }

    fileprivate static func discordTimestamp(from date: Date) -> UInt64 {
        UInt64(max(0, (date.timeIntervalSince1970 * 1_000).rounded()))
    }

    fileprivate static func resultErrorMessage(_ result: UnsafeMutablePointer<Discord_ClientResult>) -> String? {
        var error = Discord_String(ptr: nil, size: 0)
        Discord_ClientResult_Error(result, &error)
        defer { Discord_Free(error.ptr) }
        return string(from: error)
    }

    fileprivate static let presenceScopes = "openid identify sdk.social_layer_presence"

    private func withDiscordString<R>(_ value: String, _ body: (Discord_String) -> R) -> R {
        var bytes = Array(value.utf8)
        return bytes.withUnsafeMutableBufferPointer { buffer in
            body(Discord_String(ptr: buffer.baseAddress, size: buffer.count))
        }
    }

    private func withMutableDiscordString<R>(_ value: String, _ body: (inout Discord_String) -> R) -> R {
        var bytes = Array(value.utf8)
        return bytes.withUnsafeMutableBufferPointer { buffer in
            var string = Discord_String(ptr: buffer.baseAddress, size: buffer.count)
            return body(&string)
        }
    }

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

struct DiscordUser: Sendable, Equatable, Hashable {
    var id: String
    var username: String
    var discriminator: String?
    var avatar: String?
}

struct DiscordOAuthToken: Codable, Sendable, Equatable {
    enum TokenType: String, Codable, Sendable, Equatable {
        case user
        case bearer
    }

    var accessToken: String
    var refreshToken: String
    var tokenType: TokenType
    var expiresAt: Date
    var scopes: String

    var isAccessTokenUsable: Bool {
        !accessToken.isEmpty && expiresAt.timeIntervalSinceNow > 60
    }
}

private struct DiscordAuthorizationResponse: Sendable, Equatable {
    var code: String
    var redirectURI: String
    var codeVerifier: String
}

struct DiscordActivity: Sendable, Equatable {
    enum ActivityType: Int, CaseIterable, Identifiable, Sendable {
        case playing = 0
        case streaming = 1
        case listening = 2
        case watching = 3
        case competing = 5

        var id: Int { rawValue }

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

    struct Assets: Sendable, Equatable {
        var largeImage: String?
        var largeText: String?
        var smallImage: String?
        var smallText: String?
    }

    struct Timestamps: Sendable, Equatable {
        var start: Date?
        var end: Date?
    }

    struct Party: Sendable, Equatable {
        var id: String?
        var currentSize: Int?
        var maxSize: Int?
    }

    var name: String?
    var state: String?
    var details: String?
    var assets = Assets()
    var timestamps = Timestamps()
    var party = Party()
    var type: ActivityType = .playing
}

@MainActor
final class PresencePriorityController {
    static let shared = PresencePriorityController()

    private var enforcementTask: Task<Void, Never>?
    private var isReapplying = false
    private let enforcementIntervalNanoseconds: UInt64 = 8_000_000_000

    private init() {}

    func start() {
        guard enforcementTask == nil, !AutomationLaunchOptions.isUITesting else { return }
        enforcementTask = Task { [weak self] in
            guard let self else { return }
            await enforceAppliedPresenceIfNeeded()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: enforcementIntervalNanoseconds)
                await enforceAppliedPresenceIfNeeded()
            }
        }
    }

    func stop() {
        enforcementTask?.cancel()
        enforcementTask = nil
    }

    func enforceAppliedPresenceIfNeeded() async {
        guard !isReapplying else { return }
        guard await ConfigUtility.shared.isPresencePriorityEnabled() else { return }
        guard let appliedPresence = await ConfigUtility.shared.currentAppliedCustomPresence() else { return }

        do {
            let currentActivity = try await DiscordSDKManager.shared.currentPresenceActivity()
            guard currentActivity?.matches(appliedPresence) != true else { return }

            isReapplying = true
            defer { isReapplying = false }

            try await DiscordSDKManager.shared.updateActivity(
                name: appliedPresence.title.nilIfEmpty ?? "CraftPresence",
                state: appliedPresence.state.nilIfEmpty,
                details: appliedPresence.details.nilIfEmpty,
                largeImageKey: appliedPresence.largeImageKey.nilIfEmpty,
                largeImageText: appliedPresence.largeImageText.nilIfEmpty,
                smallImageKey: appliedPresence.smallImageKey.nilIfEmpty,
                smallImageText: appliedPresence.smallImageText.nilIfEmpty,
                partyID: appliedPresence.partyID,
                partyCurrent: appliedPresence.partyCurrentValue,
                partyMax: appliedPresence.partyMaxValue,
                start: appliedPresence.usesElapsedTime ? appliedPresence.elapsedStartDate : nil,
                activityType: appliedPresence.activityType.discordActivityType
            )
        } catch {
            #if DEBUG
            print("Failed to enforce applied Presence priority: \(error)")
            #endif
        }
    }
}

enum DiscordSDKError: Error, LocalizedError, Sendable, Equatable {
    case invalidApplicationID(String)
    case notConfigured
    case unauthorized
    case unsupportedPlatform
    case sdk(String)

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

private extension DiscordActivity {
    func matches(_ preset: CustomPresencePreset) -> Bool {
        stringValue(name) == stringValue(preset.title)
            && stringValue(details) == stringValue(preset.details)
            && stringValue(state) == stringValue(preset.state)
            && stringValue(assets.largeImage) == stringValue(preset.largeImageKey)
            && stringValue(assets.largeText) == stringValue(preset.largeImageText)
            && stringValue(assets.smallImage) == stringValue(preset.smallImageKey)
            && stringValue(assets.smallText) == stringValue(preset.smallImageText)
            && type == preset.activityType.discordActivityType
            && timestampsMatch(preset)
            && partyMatches(preset)
    }

    private func timestampsMatch(_ preset: CustomPresencePreset) -> Bool {
        guard preset.usesElapsedTime else {
            return timestamps.start == nil
        }
        guard let expectedStart = preset.elapsedStartDate,
              let actualStart = timestamps.start else {
            return false
        }
        return abs(actualStart.timeIntervalSince(expectedStart)) < 2
    }

    private func partyMatches(_ preset: CustomPresencePreset) -> Bool {
        if preset.partyID == nil {
            return party.currentSize == nil && party.maxSize == nil
        }
        return party.currentSize == preset.partyCurrentValue
            && party.maxSize == preset.partyMaxValue
    }

    private func stringValue(_ value: String?) -> String? {
        value?.nilIfEmpty
    }
}

#if canImport(discord_partner_sdk)
private final class DiscordAuthorizationCallbackBox {
    var codeVerifier = ""
    let completion: (Result<DiscordAuthorizationResponse, DiscordSDKError>) -> Void

    init(completion: @escaping (Result<DiscordAuthorizationResponse, DiscordSDKError>) -> Void) {
        self.completion = completion
    }

    func withCodeVerifier(_ codeVerifier: String) -> DiscordAuthorizationCallbackBox {
        self.codeVerifier = codeVerifier
        return self
    }
}

private final class DiscordTokenCallbackBox {
    let completion: (Result<DiscordOAuthToken, DiscordSDKError>) -> Void

    init(completion: @escaping (Result<DiscordOAuthToken, DiscordSDKError>) -> Void) {
        self.completion = completion
    }
}

private final class DiscordFetchUserCallbackBox {
    let completion: (Result<DiscordUser, DiscordSDKError>) -> Void

    init(completion: @escaping (Result<DiscordUser, DiscordSDKError>) -> Void) {
        self.completion = completion
    }
}

private final class DiscordVoidCallbackBox {
    let completion: ((Result<Void, DiscordSDKError>) -> Void)?

    init(completion: ((Result<Void, DiscordSDKError>) -> Void)?) {
        self.completion = completion
    }
}

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

private extension DiscordActivity.ActivityType {
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

private extension DiscordActivity {
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

    private static func requiredString(_ getter: (UnsafeMutablePointer<Discord_String>?) -> Void) -> String? {
        var string = Discord_String(ptr: nil, size: 0)
        getter(&string)
        defer { Discord_Free(string.ptr) }
        return DiscordSDKManager.string(from: string)?.nilIfEmpty
    }

    private static func optionalString(_ getter: (UnsafeMutablePointer<Discord_String>?) -> Bool) -> String? {
        var string = Discord_String(ptr: nil, size: 0)
        guard getter(&string) else { return nil }
        defer { Discord_Free(string.ptr) }
        return DiscordSDKManager.string(from: string)?.nilIfEmpty
    }

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

private extension DiscordOAuthToken.TokenType {
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

private final class DiscordTokenStore {
    private let service = "CraftPresence.DiscordOAuth"
    private let account = "DiscordOAuthToken"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

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

    func save(_ token: DiscordOAuthToken) {
        guard let data = try? encoder.encode(token) else { return }
        delete()

        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
