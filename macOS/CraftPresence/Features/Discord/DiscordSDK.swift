//
//  DiscordSDK.swift
//  CraftPresence

import Foundation
import Combine

/// Resolves Discord application settings from app configuration.
enum DiscordAppConfig {
    static var applicationId: String? {
        // 1) Try Info.plist first
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "APPLICATION_ID") as? String, !plistValue.isEmpty {
            return plistValue
        }
        // 2) Then environment variable
        if let env = ProcessInfo.processInfo.environment["APPLICATION_ID"], !env.isEmpty {
            return env
        }
        return nil
    }

    static func validationError(for applicationId: String?) -> DiscordSDKError? {
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

/// Central manager that bridges the app to the Discord SDK wrapper.
/// - Provides: SDK initialization, authorization, current user loading, and Rich Presence updates.
final class DiscordSDKManager: ObservableObject {
    static let shared = DiscordSDKManager()

    /// Current Authentication Status
    /// High-level authorization state exposed to the UI layer.
    public enum AuthorizationStatus: Sendable, Equatable {
        case authorized
        case unauthorized
        case unknown
    }

    /// User-facing SDK lifecycle state rendered on the overview dashboard.
    public enum DashboardStatus: Sendable, Equatable {
        case notConfigured
        case configured
        case authorizing
        case connecting
        case ready
        case unauthorized
        case failed

        public var localizationKey: String {
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

    private enum LifecycleState: Sendable {
        case idle
        case configured
        case authorizing
        case awaitingConnection
        case authorized
        case failed
    }

    // MARK: - Published State
    /// Current high-level authorization status for the Discord session.
    @Published private(set) var authorizationStatus: AuthorizationStatus = .unknown

    /// Current authorized Discord user, when user data is available.
    @Published private(set) var currentUser: DiscordUser? = nil

    /// Dashboard-facing setup, authorization, and connection state.
    @Published private(set) var dashboardStatus: DashboardStatus = .notConfigured

    /// Last SDK or configuration error intended for UI display.
    @Published private(set) var lastErrorMessage: String? = nil

    // MARK: - Private State
    private let queue = DispatchQueue(label: "discord.sdk.manager", qos: .userInitiated)
    private var wrapper: DiscordppWrapper?
    private var callbackTimer: DispatchSourceTimer?
    private var processActivity: NSObjectProtocol?
    private var configuredApplicationId: String?
    private var sessionID: UInt64 = 0
    private var lifecycleState: LifecycleState = .idle
    private var pendingAuthorizationCompletions: [((Result<DiscordUser, DiscordSDKError>) -> Void)?] = []
    private var lastConfigurationError: DiscordSDKError?

    private init() {}
}

// MARK: - Public API
extension DiscordSDKManager {
    /// Initializes or reconfigures the Discord SDK wrapper for the current application identifier.
    /// - Parameters:
    ///   - applicationId: Application ID of Discord Developer Portal
    ///   - autoAuthorize: Whether to attempt automatic authentication at the start of the app
    func configure(applicationId: String? = DiscordAppConfig.applicationId, autoAuthorize: Bool = true) {
        if let validationError = DiscordAppConfig.validationError(for: applicationId) {
            queue.sync {
                self.sessionID &+= 1
                self.stopCallbackPumpLocked()
                self.wrapper = nil
                self.configuredApplicationId = nil
                self.lifecycleState = .failed
                self.pendingAuthorizationCompletions.removeAll()
                self.lastConfigurationError = validationError
            }
            DispatchQueue.main.async {
                self.authorizationStatus = .unauthorized
                self.currentUser = nil
                self.dashboardStatus = .failed
                self.lastErrorMessage = validationError.localizedDescription
            }
            return
        }

        let normalizedApplicationId = applicationId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var shouldResetUI = false
        var shouldStartCallbackPump = false
        var shouldAuthorize = false

        queue.sync {
            let isSameConfiguration = self.configuredApplicationId == normalizedApplicationId && self.wrapper != nil
            if isSameConfiguration {
                shouldStartCallbackPump = autoAuthorize && self.callbackTimer == nil
                shouldAuthorize = autoAuthorize && !self.isAuthorizationInFlightLocked && !(self.wrapper?.isAuthorized() ?? false)
                return
            }

            self.sessionID &+= 1
            self.stopCallbackPumpLocked()
            self.wrapper = DiscordppWrapper(std.string(normalizedApplicationId))
            self.configuredApplicationId = normalizedApplicationId
            self.lifecycleState = .configured
            self.pendingAuthorizationCompletions.removeAll()
            self.lastConfigurationError = nil
            shouldResetUI = true
            shouldStartCallbackPump = autoAuthorize
            shouldAuthorize = autoAuthorize
        }

        if shouldResetUI {
            DispatchQueue.main.async {
                self.authorizationStatus = .unknown
                self.currentUser = nil
                self.dashboardStatus = .configured
                self.lastErrorMessage = nil
            }
        }

        if shouldStartCallbackPump {
            startCallbackPump()
        }

        if shouldAuthorize {
            authorizeIfNeeded()
        }
    }

    /// Checks the current authentication state and starts authorization only when required.
    func authorizeIfNeeded(completion: ((Result<DiscordUser, DiscordSDKError>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self else {
                completion?(.failure(.notConfigured))
                return
            }
            
            guard self.wrapper != nil else {
                completion?(.failure(self.configurationFailureLocked))
                return
            }
            if self.callbackTimer == nil {
                self.startCallbackPumpLocked()
            }

            let sessionID = self.sessionID

            if self.wrapper?.isAuthorized() == true {
                self.lifecycleState = .authorized
                DispatchQueue.main.async {
                    self.authorizationStatus = .authorized
                    self.dashboardStatus = .connecting
                    self.lastErrorMessage = nil
                }
                self.fetchCurrentUser(sessionID: sessionID, completion: completion)
                return
            }

            self.pendingAuthorizationCompletions.append(completion)

            if self.isAuthorizationInFlightLocked {
                return
            }

            self.lifecycleState = .authorizing

            // Retain a small Swift context until the C callback completes.
            let context = Unmanaged.passRetained(AuthorizationContext(sessionID: sessionID)).toOpaque()

            DispatchQueue.main.async {
                self.authorizationStatus = .unknown
                self.dashboardStatus = .authorizing
                self.lastErrorMessage = nil
            }
            
            // C-style callback invoked by the C++ Discord wrapper.
            let callback: AuthorizeCallback = { context, success, errorPtr in
                let authorizationContext = Unmanaged<AuthorizationContext>.fromOpaque(context!).takeRetainedValue()
                let errorMessage = errorPtr.map { String(cString: $0) }

                if success {
                    DiscordSDKManager.shared.queue.async {
                        guard DiscordSDKManager.shared.sessionID == authorizationContext.sessionID else {
                            return
                        }
                        print("[DiscordSDKManager] Authorization callback - SUCCESS")
                        DiscordSDKManager.shared.lifecycleState = .awaitingConnection
                        DispatchQueue.main.async {
                            DiscordSDKManager.shared.authorizationStatus = .authorized
                            DiscordSDKManager.shared.dashboardStatus = .connecting
                            DiscordSDKManager.shared.lastErrorMessage = nil
                        }

                        let completions = DiscordSDKManager.shared.pendingAuthorizationCompletions
                        DiscordSDKManager.shared.pendingAuthorizationCompletions.removeAll()
                        DiscordSDKManager.shared.waitForConnectionAndFetchUser(
                            sessionID: authorizationContext.sessionID,
                            completions: completions
                        )
                    }
                } else {
                    DiscordSDKManager.shared.queue.async {
                        guard DiscordSDKManager.shared.sessionID == authorizationContext.sessionID else {
                            return
                        }
                        DiscordSDKManager.shared.lifecycleState = .failed
                        let completions = DiscordSDKManager.shared.pendingAuthorizationCompletions
                        DiscordSDKManager.shared.pendingAuthorizationCompletions.removeAll()
                        let message = errorMessage ?? "Unknown error"
                        DispatchQueue.main.async {
                            DiscordSDKManager.shared.authorizationStatus = .unauthorized
                            DiscordSDKManager.shared.dashboardStatus = .failed
                            DiscordSDKManager.shared.lastErrorMessage = message
                            print("[DiscordSDKManager] Authorization callback - FAILED: \(message)")
                            completions.forEach { $0?(.failure(.sdk(message))) }
                        }
                    }
                }
            }
            
            // Call through the existing wrapper instance so SDK state stays attached to this session.
            self.wrapper?.authorize(context, callback)
        }
    }

    /// Logs out the currently authorized Discord user.
    func logout(completion: ((Result<Void, DiscordSDKError>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self, self.wrapper != nil else {
                completion?(.failure(self?.configurationFailureLocked ?? .notConfigured))
                return
            }
            
            let context = Unmanaged.passRetained(completion as AnyObject).toOpaque()
            
            let callback: LogoutCallback = { context, success, errorPtr in
                let completion = Unmanaged<AnyObject>.fromOpaque(context!).takeRetainedValue() as? (Result<Void, DiscordSDKError>) -> Void
                
                // Copy the C++ string while the callback pointer is still valid.
                let errorMessage = errorPtr.map { String(cString: $0) }
                
                DiscordSDKManager.shared.queue.async {
                    if success {
                        DiscordSDKManager.shared.sessionID &+= 1
                        DiscordSDKManager.shared.lifecycleState = .configured
                        DiscordSDKManager.shared.pendingAuthorizationCompletions.removeAll()
                        DiscordSDKManager.shared.stopCallbackPumpLocked()
                        DispatchQueue.main.async {
                            DiscordSDKManager.shared.authorizationStatus = .unauthorized
                            DiscordSDKManager.shared.currentUser = nil
                            DiscordSDKManager.shared.dashboardStatus = .unauthorized
                            DiscordSDKManager.shared.lastErrorMessage = nil
                            completion?(.success(()))
                        }
                    } else {
                        let message = errorMessage ?? "Unknown error"
                        DiscordSDKManager.shared.lifecycleState = .failed
                        DispatchQueue.main.async {
                            DiscordSDKManager.shared.dashboardStatus = .failed
                            DiscordSDKManager.shared.lastErrorMessage = message
                            completion?(.failure(.sdk(message)))
                        }
                    }
                }
            }
            
            self.wrapper?.logout(context, callback)
        }
    }

    /// Fetches the current Discord user associated with the active SDK session.
    func fetchCurrentUser(completion: ((Result<DiscordUser, DiscordSDKError>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self else {
                completion?(.failure(.notConfigured))
                return
            }
            self.fetchCurrentUser(sessionID: self.sessionID, completion: completion)
        }
    }

    private func fetchCurrentUser(
        sessionID expectedSessionID: UInt64,
        completion: ((Result<DiscordUser, DiscordSDKError>) -> Void)? = nil
    ) {
        queue.async { [weak self] in
            guard let self, self.wrapper != nil else {
                completion?(.failure(self?.configurationFailureLocked ?? .notConfigured))
                return
            }

            guard self.sessionID == expectedSessionID else {
                completion?(.failure(.sdk("Discord session changed during user fetch.")))
                return
            }

            let context = Unmanaged.passRetained(UserRequestContext(sessionID: expectedSessionID, completion: completion)).toOpaque()
            
            let callback: UserCallback = { context, success, idPtr, usernamePtr, errorPtr in
                let requestContext = Unmanaged<UserRequestContext>.fromOpaque(context!).takeRetainedValue()
                
                // Copy C++ strings immediately while callback pointers are still valid.
                let id: String
                let username: String
                let errorMessage: String?
                
                if success {
                    id = idPtr.map { String(cString: $0) } ?? ""
                    username = usernamePtr.map { String(cString: $0) } ?? ""
                    errorMessage = nil
                    
                    // Log after copying so the bytes reflect Swift-owned strings.
                    print("[DiscordSDKManager] Received user - ID: \(id), Username: \(username)")
                    print("[DiscordSDKManager] ID bytes: \(id.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))")
                    print("[DiscordSDKManager] Username bytes: \(username.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))")
                } else {
                    id = ""
                    username = ""
                    errorMessage = errorPtr.map { String(cString: $0) } ?? "Unknown error"
                }
                
                // Deliver copied strings to the main queue.
                DiscordSDKManager.shared.queue.async {
                    guard DiscordSDKManager.shared.sessionID == requestContext.sessionID else {
                        requestContext.completion?(.failure(.sdk("Discord session changed during user fetch.")))
                        return
                    }

                    DispatchQueue.main.async {
                        if success {
                            let user = DiscordUser(
                                id: id,
                                username: username,
                                discriminator: nil
                            )
                            DiscordSDKManager.shared.currentUser = user
                            DiscordSDKManager.shared.authorizationStatus = .authorized
                            DiscordSDKManager.shared.lifecycleState = .authorized
                            DiscordSDKManager.shared.dashboardStatus = .ready
                            DiscordSDKManager.shared.lastErrorMessage = nil
                            requestContext.completion?(.success(user))
                        } else {
                            DiscordSDKManager.shared.authorizationStatus = .unauthorized
                            DiscordSDKManager.shared.currentUser = nil
                            DiscordSDKManager.shared.lifecycleState = .failed
                            DiscordSDKManager.shared.dashboardStatus = .failed
                            DiscordSDKManager.shared.lastErrorMessage = errorMessage ?? "Unknown error"
                            requestContext.completion?(.failure(.sdk(errorMessage ?? "Unknown error")))
                        }
                    }
                }
            }
            
            self.wrapper?.getCurrentUser(context, callback)
        }
    }
    
    /// Polls the SDK connection state until it becomes ready, then loads the current user.
    private func waitForConnectionAndFetchUser(
        sessionID expectedSessionID: UInt64,
        timeout: TimeInterval = 10.0,
        pollInterval: TimeInterval = 0.1,
        completions: [((Result<DiscordUser, DiscordSDKError>) -> Void)?]
    ) {
        let startTime = Date()
        
        func checkConnection() {
            queue.async { [weak self] in
                guard let self else {
                    completions.forEach { $0?(.failure(.notConfigured)) }
                    return
                }

                guard self.sessionID == expectedSessionID else {
                    completions.forEach { $0?(.failure(.sdk("Discord session changed while waiting for connection."))) }
                    return
                }

                guard self.isConnectionAwaitActiveLocked else {
                    completions.forEach { $0?(.failure(.sdk("Discord authorization flow was interrupted."))) }
                    return
                }

                // Check whether the SDK is ready to return user data.
                let connected = self.wrapper?.isConnected() ?? false
                
                if connected {
                    // Connection is ready; fetch user details.
                    let elapsed = Date().timeIntervalSince(startTime)
                    print("[DiscordSDKManager] SDK connected after \(String(format: "%.2f", elapsed))s, fetching user...")
                    let combinedCompletion: (Result<DiscordUser, DiscordSDKError>) -> Void = { result in
                        completions.forEach { $0?(result) }
                    }
                    self.fetchCurrentUser(sessionID: expectedSessionID, completion: combinedCompletion)
                } else {
                    // Check for timeout before scheduling another poll.
                    let elapsed = Date().timeIntervalSince(startTime)
                    if elapsed >= timeout {
                        print("[DiscordSDKManager] Connection timeout after \(String(format: "%.2f", elapsed))s")
                        self.lifecycleState = .failed
                        DispatchQueue.main.async {
                            self.authorizationStatus = .unauthorized
                            self.currentUser = nil
                            self.dashboardStatus = .failed
                            self.lastErrorMessage = "Connection timeout: SDK did not connect within \(timeout)s"
                        }
                        let error: Result<DiscordUser, DiscordSDKError> = .failure(.sdk("Connection timeout: SDK did not connect within \(timeout)s"))
                        completions.forEach { $0?(error) }
                    } else {
                        // Poll again after a short delay.
                        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + pollInterval) {
                            checkConnection()
                        }
                    }
                }
            }
        }
        
        // Delay the first check briefly because Connect() was just requested.
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
            checkConnection()
        }
    }

    /// Sends a Rich Presence activity update through the Discord SDK wrapper.
    func updateActivity(
        name: String? = nil,
        state: String?,
        details: String?,
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
        queue.async { [weak self] in
            guard let self, self.wrapper != nil else {
                completion?(.failure(self?.configurationFailureLocked ?? .notConfigured))
                return
            }

            let sessionID = self.sessionID
            if self.isReadyForActivityUpdateLocked {
                self.performActivityUpdate(
                    sessionID: sessionID,
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
                    activityType: activityType,
                    completion: completion
                )
                return
            }

            self.ensureReadyForActivityUpdate(sessionID: sessionID) { [weak self] result in
                guard let self else {
                    completion?(.failure(.notConfigured))
                    return
                }
                switch result {
                case .success:
                    self.queue.async {
                        guard self.sessionID == sessionID else {
                            completion?(.failure(.sdk("Discord session changed before activity update.")))
                            return
                        }
                        guard self.isReadyForActivityUpdateLocked else {
                            completion?(.failure(.unauthorized))
                            return
                        }
                        self.performActivityUpdate(
                            sessionID: sessionID,
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
                            activityType: activityType,
                            completion: completion
                        )
                    }
                case .failure(let error):
                    completion?(.failure(error))
                }
            }
        }
    }

    /// Clears the currently published Rich Presence activity.
    func clearActivity(completion: ((Result<Void, DiscordSDKError>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self, self.wrapper != nil else {
                completion?(.failure(self?.configurationFailureLocked ?? .notConfigured))
                return
            }

            let sessionID = self.sessionID
            let context = Unmanaged.passRetained(ActivityRequestContext(sessionID: sessionID, completion: completion)).toOpaque()
            
            let callback: ActivityCallback = { context, success, errorPtr in
                let requestContext = Unmanaged<ActivityRequestContext>.fromOpaque(context!).takeRetainedValue()
                
                // Copy the C++ error string while the callback pointer is valid.
                let errorMessage = errorPtr.map { String(cString: $0) }
                
                DiscordSDKManager.shared.queue.async {
                    guard DiscordSDKManager.shared.sessionID == requestContext.sessionID else {
                        requestContext.completion?(.failure(.sdk("Discord session changed during activity clear.")))
                        return
                    }
                    DispatchQueue.main.async {
                        if success {
                            requestContext.completion?(.success(()))
                        } else {
                            let message = errorMessage ?? "Unknown error"
                            requestContext.completion?(.failure(.sdk(message)))
                        }
                    }
                }
            }
            
            self.wrapper?.clearActivity(context, callback)
        }
    }
}

// MARK: - Async/Await Convenience
extension DiscordSDKManager {
    /// Async wrapper around `authorizeIfNeeded(completion:)`.
    func authorizeIfNeeded() async throws -> DiscordUser {
        try await withCheckedThrowingContinuation { cont in
            authorizeIfNeeded { cont.resume(with: $0.mapError { $0 }) }
        }
    }

    /// Async wrapper around `logout(completion:)`.
    func logout() async throws {
        try await withCheckedThrowingContinuation { cont in
            logout { cont.resume(with: $0.mapError { $0 }) }
        }
    }

    /// Async wrapper around `fetchCurrentUser(completion:)`.
    func currentUser() async throws -> DiscordUser {
        try await withCheckedThrowingContinuation { cont in
            fetchCurrentUser { cont.resume(with: $0.mapError { $0 }) }
        }
    }

    func updateActivity(
        name: String? = nil,
        state: String?,
        details: String?,
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
        try await withCheckedThrowingContinuation { cont in
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
            ) { cont.resume(with: $0.mapError { $0 }) }
        }
    }

    func clearActivity() async throws {
        try await withCheckedThrowingContinuation { cont in
            clearActivity { cont.resume(with: $0.mapError { $0 }) }
        }
    }
}

// MARK: - Internal Helpers
private extension DiscordSDKManager {
    var configurationFailureLocked: DiscordSDKError {
        lastConfigurationError ?? .notConfigured
    }

    var isReadyForActivityUpdateLocked: Bool {
        isAuthorizedStateLocked && wrapper?.isAuthorized() == true && wrapper?.isConnected() == true
    }

    var isAuthorizationInFlightLocked: Bool {
        switch lifecycleState {
        case .authorizing, .awaitingConnection:
            return true
        default:
            return false
        }
    }

    var isConnectionAwaitActiveLocked: Bool {
        switch lifecycleState {
        case .awaitingConnection, .authorized:
            return true
        default:
            return false
        }
    }

    var isAuthorizedStateLocked: Bool {
        switch lifecycleState {
        case .authorized:
            return true
        default:
            return false
        }
    }

    func ensureReadyForActivityUpdate(
        sessionID expectedSessionID: UInt64,
        completion: @escaping (Result<Void, DiscordSDKError>) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else {
                completion(.failure(.notConfigured))
                return
            }

            guard self.sessionID == expectedSessionID else {
                completion(.failure(.sdk("Discord session changed before authorization.")))
                return
            }

            guard self.wrapper != nil else {
                completion(.failure(.notConfigured))
                return
            }

            if self.isReadyForActivityUpdateLocked {
                self.lifecycleState = .authorized
                DispatchQueue.main.async {
                    self.authorizationStatus = .authorized
                }
                completion(.success(()))
                return
            }

            self.authorizeIfNeeded { [weak self] result in
                guard let self else {
                    completion(.failure(.notConfigured))
                    return
                }
                switch result {
                case .success:
                    self.queue.async {
                        guard self.sessionID == expectedSessionID else {
                            completion(.failure(.sdk("Discord session changed before activity update.")))
                            return
                        }
                        guard self.isReadyForActivityUpdateLocked else {
                            completion(.failure(.unauthorized))
                            return
                        }
                        self.lifecycleState = .authorized
                        completion(.success(()))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    func performActivityUpdate(
        sessionID: UInt64,
        name: String?,
        state: String?,
        details: String?,
        largeImageKey: String?,
        largeImageText: String?,
        smallImageKey: String?,
        smallImageText: String?,
        partyID: String?,
        partyCurrent: Int?,
        partyMax: Int?,
        start: Date?,
        end: Date?,
        activityType: DiscordActivity.ActivityType,
        completion: ((Result<Void, DiscordSDKError>) -> Void)?
    ) {
        let startTimestamp = start?.timeIntervalSince1970 ?? 0
        let endTimestamp = end?.timeIntervalSince1970 ?? 0

        let context = Unmanaged.passRetained(ActivityRequestContext(sessionID: sessionID, completion: completion)).toOpaque()

        let callback: ActivityCallback = { context, success, errorPtr in
            let requestContext = Unmanaged<ActivityRequestContext>.fromOpaque(context!).takeRetainedValue()

            let errorMessage = errorPtr.map { String(cString: $0) }

            DiscordSDKManager.shared.queue.async {
                guard DiscordSDKManager.shared.sessionID == requestContext.sessionID else {
                    requestContext.completion?(.failure(.sdk("Discord session changed during activity update.")))
                    return
                }
                DispatchQueue.main.async {
                    if success {
                        requestContext.completion?(.success(()))
                    } else {
                        let message = errorMessage ?? "Unknown error"
                        requestContext.completion?(.failure(.sdk(message)))
                    }
                }
            }
        }

        wrapper?.updateActivity(
            std.string(name ?? ""),
            std.string(state ?? ""),
            std.string(details ?? ""),
            std.string(largeImageKey ?? ""),
            std.string(largeImageText ?? ""),
            std.string(smallImageKey ?? ""),
            std.string(smallImageText ?? ""),
            std.string(partyID ?? ""),
            Int32(partyCurrent ?? 0),
            Int32(partyMax ?? 0),
            Int64(startTimestamp),
            Int64(endTimestamp),
            Int32(activityType.rawValue),
            context,
            callback
        )
    }

    func startCallbackPump() {
        queue.async { [weak self] in
            guard let self else { return }
            self.startCallbackPumpLocked()
        }
    }

    func stopCallbackPump() {
        queue.async { [weak self] in
            guard let self else { return }
            self.stopCallbackPumpLocked()
        }
    }

    func stopCallbackPumpLocked() {
        callbackTimer?.cancel()
        callbackTimer = nil
        if let activity = processActivity {
            ProcessInfo.processInfo.endActivity(activity)
            processActivity = nil
        }
    }

    func startCallbackPumpLocked() {
        stopCallbackPumpLocked()
        guard wrapper != nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(8))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.wrapper?.runCallbacks()
        }
        timer.resume()
        callbackTimer = timer
        if processActivity == nil {
            let options: ProcessInfo.ActivityOptions = [.background]
            processActivity = ProcessInfo.processInfo.beginActivity(options: options, reason: "Discord SDK callback pump")
        }
    }
}

private final class AuthorizationContext {
    let sessionID: UInt64

    init(sessionID: UInt64) {
        self.sessionID = sessionID
    }
}

private final class UserRequestContext {
    let sessionID: UInt64
    let completion: ((Result<DiscordUser, DiscordSDKError>) -> Void)?

    init(
        sessionID: UInt64,
        completion: ((Result<DiscordUser, DiscordSDKError>) -> Void)?
    ) {
        self.sessionID = sessionID
        self.completion = completion
    }
}

private final class ActivityRequestContext {
    let sessionID: UInt64
    let completion: ((Result<Void, DiscordSDKError>) -> Void)?

    init(
        sessionID: UInt64,
        completion: ((Result<Void, DiscordSDKError>) -> Void)?
    ) {
        self.sessionID = sessionID
        self.completion = completion
    }
}

// MARK: - Models and Errors
/// Discord user identity returned by the SDK.
public struct DiscordUser: Sendable, Equatable, Hashable {
    /// Discord snowflake user ID.
    public var id: String

    /// Display name or username reported by Discord.
    public var username: String

    /// Legacy discriminator, when Discord provides one.
    public var discriminator: String?

    /// Avatar image URL, when available.
    public var avatarURL: URL?

    public init(id: String, username: String, discriminator: String? = nil, avatarURL: URL? = nil) {
        self.id = id
        self.username = username
        self.discriminator = discriminator
        self.avatarURL = avatarURL
    }
}

/// Rich Presence activity model used before converting values to Discord SDK types.
public struct DiscordActivity: Sendable, Equatable {
    /// Discord Rich Presence activity category.
    public enum ActivityType: Int, CaseIterable, Identifiable, Sendable, Equatable {
        case playing = 0
        case streaming = 1
        case listening = 2
        case watching = 3
        case customStatus = 4
        case competing = 5
        case hangStatus = 6

        /// Stable identifier used by SwiftUI pickers.
        public var id: Int { rawValue }

        /// Human-readable activity type label.
        public var displayName: String {
            switch self {
            case .playing: return "Playing"
            case .streaming: return "Streaming"
            case .listening: return "Listening"
            case .watching: return "Watching"
            case .customStatus: return "Custom Status"
            case .competing: return "Competing"
            case .hangStatus: return "Hang Status"
            }
        }
    }

    /// Optional start and end times displayed by Discord.
    public struct Timestamps: Sendable, Equatable { public var start: Date?; public var end: Date? }

    /// Discord Developer Portal asset keys and tooltip labels.
    public struct Assets: Sendable, Equatable {
        public var largeImage: String?
        public var largeText: String?
        public var smallImage: String?
        public var smallText: String?
    }

    /// Party metadata displayed as current and maximum size.
    public struct Party: Sendable, Equatable {
        public var id: String?
        public var currentSize: Int?
        public var maxSize: Int?
    }

    /// Activity title shown as the primary Rich Presence label.
    public var name: String?

    /// Short status line, usually the current mode or context.
    public var state: String?

    /// Longer status line, usually the item, track, or screen name.
    public var details: String?

    /// Discord activity category.
    public var type: ActivityType = .playing

    /// Optional elapsed or remaining time values.
    public var timestamps: Timestamps = .init(start: nil, end: nil)

    /// Optional Rich Presence image assets.
    public var assets: Assets = .init(largeImage: nil, largeText: nil, smallImage: nil, smallText: nil)

    /// Optional party size metadata.
    public var party: Party = .init(id: nil, currentSize: nil, maxSize: nil)

    /// Creates an empty Rich Presence activity.
    public init() {}
}

/// Errors surfaced by the Discord SDK integration layer.
public enum DiscordSDKError: Error, LocalizedError, Sendable, Equatable {
    /// The SDK has not been configured with a valid application ID.
    case notConfigured

    /// The configured Discord application ID is missing, still a placeholder, or malformed.
    case invalidApplicationID(String)

    /// No valid Discord authorization is available for the current application ID.
    case unauthorized

    /// Native Discord SDK call failed.
    case sdk(String)

    /// Localized error text suitable for user-facing surfaces.
    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "Discord SDK가 구성되지 않았습니다. configure(applicationId:)를 먼저 호출하세요."
        case .invalidApplicationID(let message): return "Discord APPLICATION_ID 설정이 잘못되었습니다. \(message)"
        case .unauthorized: return "Discord 인증이 필요합니다."
        case .sdk(let message): return message
        }
    }
}

// MARK: - DiscordSocialSDK Bridge
// Adjust the protocol/extension below to match the type/method signature of the actual DiscordSocial SDK.
// This sample provides minimal bridge form for the project to be compiled.
private protocol _DiscordClientProto {
    var isAuthorized: Bool { get }
    init(applicationId: String)
    func authorize(completion: @escaping (Result<Void, Error>) -> Void)
    func logout(completion: @escaping (Result<Void, Error>) -> Void)
    func getCurrentUser(completion: @escaping (Result<DiscordUser, Error>) -> Void)
    func updateActivity(_ activity: DiscordActivity, completion: @escaping (Result<Void, Error>) -> Void)
    func clearActivity(completion: @escaping (Result<Void, Error>) -> Void)
}

// Implementing DiscordClient Using DiscordSDKManager
private final class DiscordClient: _DiscordClientProto {
    private let manager = DiscordSDKManager.shared
    private let appId: String
    private var _isAuthorized: Bool = false

    var isAuthorized: Bool {
        return _isAuthorized
    }

    init(applicationId: String) {
        self.appId = applicationId
        // Initialize DiscordSDKManager without starting authorization automatically.
        manager.configure(applicationId: applicationId, autoAuthorize: false)
    }

    func authorize(completion: @escaping (Result<Void, Error>) -> Void) {
        manager.authorizeIfNeeded { [weak self] result in
            switch result {
            case .success(_):
                self?._isAuthorized = true
                completion(.success(()))
            case .failure(let error):
                self?._isAuthorized = false
                completion(.failure(error))
            }
        }
    }

    func logout(completion: @escaping (Result<Void, Error>) -> Void) {
        manager.logout { [weak self] result in
            switch result {
            case .success():
                self?._isAuthorized = false
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func getCurrentUser(completion: @escaping (Result<DiscordUser, Error>) -> Void) {
        guard _isAuthorized else { 
            completion(.failure(DiscordSDKError.unauthorized))
            return 
        }
        
        manager.fetchCurrentUser { result in
            completion(result.mapError { $0 as Error })
        }
    }

    func updateActivity(_ activity: DiscordActivity, completion: @escaping (Result<Void, Error>) -> Void) {
        guard _isAuthorized else { 
            completion(.failure(DiscordSDKError.unauthorized))
            return 
        }
        
        manager.updateActivity(
            state: activity.state,
            details: activity.details,
            largeImageKey: activity.assets.largeImage,
            largeImageText: activity.assets.largeText,
            smallImageKey: activity.assets.smallImage,
            smallImageText: activity.assets.smallText,
            partyID: activity.party.id,
            partyCurrent: activity.party.currentSize,
            partyMax: activity.party.maxSize,
            start: activity.timestamps.start,
            end: activity.timestamps.end,
            activityType: activity.type
        ) { result in
            completion(result.mapError { $0 as Error })
        }
    }

    func clearActivity(completion: @escaping (Result<Void, Error>) -> Void) {
        guard _isAuthorized else { 
            completion(.failure(DiscordSDKError.unauthorized))
            return 
        }
        
        manager.clearActivity { result in
            completion(result.mapError { $0 as Error })
        }
    }
}
