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

/// Manager in charge of the Discord SDK interworking
/// - Provides initialization, authentication, user information, and Rich Presence update capabilities
final class DiscordSDKManager: ObservableObject {
    static let shared = DiscordSDKManager()

    /// Current Authentication Status
    public enum AuthorizationStatus: Sendable, Equatable {
        case authorized
        case unauthorized
        case unknown
    }

    private enum LifecycleState: Sendable {
        case idle
        case configured
        case authorizing
        case awaitingConnection
        case authorized
        case failed
    }

    // MARK: - Published State (UI 자동 업데이트용)
    @Published private(set) var authorizationStatus: AuthorizationStatus = .unknown
    @Published private(set) var currentUser: DiscordUser? = nil

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
    /// Initialize the SDK.
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
                shouldStartCallbackPump = self.callbackTimer == nil
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
            shouldStartCallbackPump = true
            shouldAuthorize = autoAuthorize
        }

        if shouldResetUI {
            DispatchQueue.main.async {
                self.authorizationStatus = .unknown
                self.currentUser = nil
            }
        }

        if shouldStartCallbackPump {
            startCallbackPump()
        }

        if shouldAuthorize {
            authorizeIfNeeded()
        }
    }

    /// Check the authentication status and try to authenticate if necessary.
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

            let sessionID = self.sessionID

            if self.wrapper?.isAuthorized() == true {
                self.lifecycleState = .authorized
                DispatchQueue.main.async {
                    self.authorizationStatus = .authorized
                }
                self.fetchCurrentUser(sessionID: sessionID, completion: completion)
                return
            }

            self.pendingAuthorizationCompletions.append(completion)

            if self.isAuthorizationInFlightLocked {
                return
            }

            self.lifecycleState = .authorizing

            // Swift 클로저를 보관할 컨텍스트 생성
            let context = Unmanaged.passRetained(AuthorizationContext(sessionID: sessionID)).toOpaque()
            
            // C 스타일 콜백 함수
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
                            print("[DiscordSDKManager] Authorization callback - FAILED: \(message)")
                            completions.forEach { $0?(.failure(.sdk(message))) }
                        }
                    }
                }
            }
            
            // self.wrapper를 직접 수정 (복사 방지)
            self.wrapper?.authorize(context, callback)
        }
    }

    /// logout the current user
    func logout(completion: ((Result<Void, DiscordSDKError>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self, self.wrapper != nil else {
                completion?(.failure(self?.configurationFailureLocked ?? .notConfigured))
                return
            }
            
            let context = Unmanaged.passRetained(completion as AnyObject).toOpaque()
            
            let callback: LogoutCallback = { context, success, errorPtr in
                let completion = Unmanaged<AnyObject>.fromOpaque(context!).takeRetainedValue() as? (Result<Void, DiscordSDKError>) -> Void
                
                // C++ 포인터가 유효할 때 즉시 복사
                let errorMessage = errorPtr.map { String(cString: $0) }
                
                DispatchQueue.main.async {
                    if success {
                        DiscordSDKManager.shared.authorizationStatus = .unauthorized
                        DiscordSDKManager.shared.currentUser = nil
                        completion?(.success(()))
                    } else {
                        let message = errorMessage ?? "Unknown error"
                        completion?(.failure(.sdk(message)))
                    }
                }
            }
            
            self.wrapper?.logout(context, callback)
        }
    }

    /// Get Current User Info
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
                
                // ⚠️ 중요: C++ 포인터가 유효할 때 즉시 Swift String으로 복사
                let id: String
                let username: String
                let errorMessage: String?
                
                if success {
                    id = idPtr.map { String(cString: $0) } ?? ""
                    username = usernamePtr.map { String(cString: $0) } ?? ""
                    errorMessage = nil
                    
                    // 문자열 디버깅 로그 (복사 직후)
                    print("[DiscordSDKManager] Received user - ID: \(id), Username: \(username)")
                    print("[DiscordSDKManager] ID bytes: \(id.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))")
                    print("[DiscordSDKManager] Username bytes: \(username.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))")
                } else {
                    id = ""
                    username = ""
                    errorMessage = errorPtr.map { String(cString: $0) } ?? "Unknown error"
                }
                
                // 복사된 문자열을 메인 큐로 전달
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
                            requestContext.completion?(.success(user))
                        } else {
                            DiscordSDKManager.shared.authorizationStatus = .unauthorized
                            DiscordSDKManager.shared.currentUser = nil
                            DiscordSDKManager.shared.lifecycleState = .failed
                            requestContext.completion?(.failure(.sdk(errorMessage ?? "Unknown error")))
                        }
                    }
                }
            }
            
            self.wrapper?.getCurrentUser(context, callback)
        }
    }
    
    /// SDK 연결 상태를 폴링하여 연결 완료 후 사용자 정보 가져오기
    /// Connect() 직후 SDK가 완전히 초기화될 때까지 대기
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

                // 연결 상태 확인
                let connected = self.wrapper?.isConnected() ?? false
                
                if connected {
                    // 연결 완료 - 사용자 정보 가져오기
                    let elapsed = Date().timeIntervalSince(startTime)
                    print("[DiscordSDKManager] SDK connected after \(String(format: "%.2f", elapsed))s, fetching user...")
                    let combinedCompletion: (Result<DiscordUser, DiscordSDKError>) -> Void = { result in
                        completions.forEach { $0?(result) }
                    }
                    self.fetchCurrentUser(sessionID: expectedSessionID, completion: combinedCompletion)
                } else {
                    // 타임아웃 확인
                    let elapsed = Date().timeIntervalSince(startTime)
                    if elapsed >= timeout {
                        print("[DiscordSDKManager] Connection timeout after \(String(format: "%.2f", elapsed))s")
                        self.lifecycleState = .failed
                        DispatchQueue.main.async {
                            self.authorizationStatus = .unauthorized
                            self.currentUser = nil
                        }
                        let error: Result<DiscordUser, DiscordSDKError> = .failure(.sdk("Connection timeout: SDK did not connect within \(timeout)s"))
                        completions.forEach { $0?(error) }
                    } else {
                        // 다시 폴링
                        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + pollInterval) {
                            checkConnection()
                        }
                    }
                }
            }
        }
        
        // 첫 번째 체크는 약간 지연 후 시작 (Connect() 호출 직후이므로)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
            checkConnection()
        }
    }

    /// Update Rich Presence
    func updateActivity(
        name: String? = nil,
        state: String?,
        details: String?,
        largeImageKey: String? = nil,
        smallImageKey: String? = nil,
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
                    smallImageKey: smallImageKey,
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
                            smallImageKey: smallImageKey,
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

    /// clear rich presence activity
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
                
                // C++ 포인터가 유효할 때 즉시 복사
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

// MARK: - Async/Await 편의 API
extension DiscordSDKManager {
    func authorizeIfNeeded() async throws -> DiscordUser {
        try await withCheckedThrowingContinuation { cont in
            authorizeIfNeeded { cont.resume(with: $0.mapError { $0 }) }
        }
    }

    func logout() async throws {
        try await withCheckedThrowingContinuation { cont in
            logout { cont.resume(with: $0.mapError { $0 }) }
        }
    }

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
        smallImageKey: String? = nil,
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
                smallImageKey: smallImageKey,
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
        smallImageKey: String?,
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
            std.string(smallImageKey ?? ""),
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
            self.stopCallbackPumpLocked()
            guard self.wrapper != nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(16), leeway: .milliseconds(8))
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                self.wrapper?.runCallbacks()
            }
            timer.resume()
            self.callbackTimer = timer
            if self.processActivity == nil {
                let options: ProcessInfo.ActivityOptions = [.background, .idleSystemSleepDisabled]
                self.processActivity = ProcessInfo.processInfo.beginActivity(options: options, reason: "Discord SDK callback pump")
            }
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

// MARK: - 모델 및 에러 타입 (SDK의 가상 타입을 래핑)
public struct DiscordUser: Sendable, Equatable, Hashable {
    public var id: String
    public var username: String
    public var discriminator: String?
    public var avatarURL: URL?

    public init(id: String, username: String, discriminator: String? = nil, avatarURL: URL? = nil) {
        self.id = id
        self.username = username
        self.discriminator = discriminator
        self.avatarURL = avatarURL
    }
}

public struct DiscordActivity: Sendable, Equatable {
    public enum ActivityType: Int, CaseIterable, Identifiable, Sendable, Equatable {
        case playing = 0
        case streaming = 1
        case listening = 2
        case watching = 3
        case customStatus = 4
        case competing = 5
        case hangStatus = 6

        public var id: Int { rawValue }

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

    public struct Timestamps: Sendable, Equatable { public var start: Date?; public var end: Date? }
    public struct Assets: Sendable, Equatable { public var largeImage: String?; public var smallImage: String? }

    public var name: String?
    public var state: String?
    public var details: String?
    public var type: ActivityType = .playing
    public var timestamps: Timestamps = .init(start: nil, end: nil)
    public var assets: Assets = .init(largeImage: nil, smallImage: nil)

    public init() {}
}

public enum DiscordSDKError: Error, LocalizedError, Sendable, Equatable {
    case notConfigured
    case invalidApplicationID(String)
    case unauthorized
    case sdk(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "Discord SDK가 구성되지 않았습니다. configure(applicationId:)를 먼저 호출하세요."
        case .invalidApplicationID(let message): return "Discord APPLICATION_ID 설정이 잘못되었습니다. \(message)"
        case .unauthorized: return "Discord 인증이 필요합니다."
        case .sdk(let message): return message
        }
    }
}

// MARK: - DiscordSocialSDK 가정 인터페이스 브릿지
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
        // DiscordSDKManager 초기화
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
            smallImageKey: activity.assets.smallImage,
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
