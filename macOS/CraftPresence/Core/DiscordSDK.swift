//
//  DiscordSDK.swift
//  CraftPresence

import Foundation

/// Discord 애플리케이션 설정 값 보관
/// - 환경변수 `APPLICATION_ID`가 있으면 우선 사용, 없으면 하드코딩된 기본값 사용
enum DiscordAppConfig {
    /// 하드코딩 기본값: 필요 시 실제 Application ID로 교체하세요.
    private static let fallbackId = "YOUR_APPLICATION_ID"

    static var applicationId: String {
        if let env = ProcessInfo.processInfo.environment["APPLICATION_ID"], !env.isEmpty {
            return env
        }
        return fallbackId
    }
}

/// Discord SDK 연동을 담당하는 매니저
/// - 초기화, 인증, 사용자 정보, 활동(Rich Presence) 업데이트 기능 제공
final class DiscordSDKManager: @unchecked Sendable {
    static let shared = DiscordSDKManager()

    // MARK: - Private State
    private let queue = DispatchQueue(label: "discord.sdk.manager", qos: .userInitiated)
    private var wrapper: DiscordppWrapper?

    private init() {}
}

// MARK: - Public API
extension DiscordSDKManager {
    /// Initialize the SDK.
    /// - Parameters:
    ///   - applicationId: Application ID of Discord Developer Portal
    ///   - autoAuthorize: Whether to attempt automatic authentication at the start of the app
    func configure(applicationId: String = DiscordAppConfig.applicationId, autoAuthorize: Bool = true) {
        queue.sync {
            self.wrapper = DiscordppWrapper(std.string(applicationId))
        }
        if autoAuthorize { authorizeIfNeeded() }
    }

    /// 인증 상태를 확인하고 필요 시 인증을 시도합니다.
    func authorizeIfNeeded(completion: ((Result<DiscordUser, DiscordSDKError>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self, var wrapper = self.wrapper else {
                completion?(.failure(.notConfigured))
                return
            }
            
            if wrapper.isAuthorized() {
                self.fetchCurrentUser(completion: completion)
                return
            }
            
            // Swift 클로저를 보관할 컨텍스트 생성
            let context = Unmanaged.passRetained(completion as AnyObject).toOpaque()
            
            // C 스타일 콜백 함수
            let callback: AuthorizeCallback = { context, success, errorPtr in
                let completion = Unmanaged<AnyObject>.fromOpaque(context!).takeRetainedValue() as? (Result<DiscordUser, DiscordSDKError>) -> Void
                
                DispatchQueue.main.async {
                    if success {
                        DiscordSDKManager.shared.fetchCurrentUser(completion: completion)
                    } else {
                        let message = errorPtr.map { String(cString: $0) } ?? "Unknown error"
                        completion?(.failure(.sdk(message)))
                    }
                }
            }
            
            wrapper.authorize(context, callback)
        }
    }

    /// logout the current user
    func logout(completion: ((Result<Void, DiscordSDKError>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self, var wrapper = self.wrapper else {
                completion?(.failure(.notConfigured))
                return
            }
            
            let context = Unmanaged.passRetained(completion as AnyObject).toOpaque()
            
            let callback: LogoutCallback = { context, success, errorPtr in
                let completion = Unmanaged<AnyObject>.fromOpaque(context!).takeRetainedValue() as? (Result<Void, DiscordSDKError>) -> Void
                
                DispatchQueue.main.async {
                    if success {
                        completion?(.success(()))
                    } else {
                        let message = errorPtr.map { String(cString: $0) } ?? "Unknown error"
                        completion?(.failure(.sdk(message)))
                    }
                }
            }
            
            wrapper.logout(context, callback)
        }
    }

    /// Get Current User Info
    func fetchCurrentUser(completion: ((Result<DiscordUser, DiscordSDKError>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self, var wrapper = self.wrapper else {
                completion?(.failure(.notConfigured))
                return
            }
            
            let context = Unmanaged.passRetained(completion as AnyObject).toOpaque()
            
            let callback: UserCallback = { context, success, idPtr, usernamePtr, errorPtr in
                let completion = Unmanaged<AnyObject>.fromOpaque(context!).takeRetainedValue() as? (Result<DiscordUser, DiscordSDKError>) -> Void
                
                DispatchQueue.main.async {
                    if success {
                        let id = idPtr.map { String(cString: $0) } ?? ""
                        let username = usernamePtr.map { String(cString: $0) } ?? ""
                        let user = DiscordUser(
                            id: id,
                            username: username,
                            discriminator: nil
                        )
                        completion?(.success(user))
                    } else {
                        let message = errorPtr.map { String(cString: $0) } ?? "Unknown error"
                        completion?(.failure(.sdk(message)))
                    }
                }
            }
            
            wrapper.getCurrentUser(context, callback)
        }
    }

    /// Update Rich Presence
    func updateActivity(
        state: String?,
        details: String?,
        largeImageKey: String? = nil,
        smallImageKey: String? = nil,
        start: Date? = nil,
        end: Date? = nil,
        completion: ((Result<Void, DiscordSDKError>) -> Void)? = nil
    ) {
        queue.async { [weak self] in
            guard let self, var wrapper = self.wrapper else {
                completion?(.failure(.notConfigured))
                return
            }
            
            let startTimestamp = start?.timeIntervalSince1970 ?? 0
            let endTimestamp = end?.timeIntervalSince1970 ?? 0
            
            let context = Unmanaged.passRetained(completion as AnyObject).toOpaque()
            
            let callback: ActivityCallback = { context, success, errorPtr in
                let completion = Unmanaged<AnyObject>.fromOpaque(context!).takeRetainedValue() as? (Result<Void, DiscordSDKError>) -> Void
                
                DispatchQueue.main.async {
                    if success {
                        completion?(.success(()))
                    } else {
                        let message = errorPtr.map { String(cString: $0) } ?? "Unknown error"
                        completion?(.failure(.sdk(message)))
                    }
                }
            }
            
            wrapper.updateActivity(
                std.string(state ?? ""),
                std.string(details ?? ""),
                std.string(largeImageKey ?? ""),
                std.string(smallImageKey ?? ""),
                Int64(startTimestamp),
                Int64(endTimestamp),
                context,
                callback
            )
        }
    }

    /// clear rich presence activity
    func clearActivity(completion: ((Result<Void, DiscordSDKError>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self, var wrapper = self.wrapper else {
                completion?(.failure(.notConfigured))
                return
            }
            
            let context = Unmanaged.passRetained(completion as AnyObject).toOpaque()
            
            let callback: ActivityCallback = { context, success, errorPtr in
                let completion = Unmanaged<AnyObject>.fromOpaque(context!).takeRetainedValue() as? (Result<Void, DiscordSDKError>) -> Void
                
                DispatchQueue.main.async {
                    if success {
                        completion?(.success(()))
                    } else {
                        let message = errorPtr.map { String(cString: $0) } ?? "Unknown error"
                        completion?(.failure(.sdk(message)))
                    }
                }
            }
            
            wrapper.clearActivity(context, callback)
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
        state: String?,
        details: String?,
        largeImageKey: String? = nil,
        smallImageKey: String? = nil,
        start: Date? = nil,
        end: Date? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { cont in
            updateActivity(
                state: state,
                details: details,
                largeImageKey: largeImageKey,
                smallImageKey: smallImageKey,
                start: start,
                end: end
            ) { cont.resume(with: $0.mapError { $0 }) }
        }
    }

    func clearActivity() async throws {
        try await withCheckedThrowingContinuation { cont in
            clearActivity { cont.resume(with: $0.mapError { $0 }) }
        }
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
    public struct Timestamps: Sendable, Equatable { public var start: Date?; public var end: Date? }
    public struct Assets: Sendable, Equatable { public var largeImage: String?; public var smallImage: String? }

    public var state: String?
    public var details: String?
    public var timestamps: Timestamps = .init(start: nil, end: nil)
    public var assets: Assets = .init(largeImage: nil, smallImage: nil)

    public init() {}
}

public enum DiscordSDKError: Error, LocalizedError, Sendable, Equatable {
    case notConfigured
    case unauthorized
    case sdk(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "Discord SDK가 구성되지 않았습니다. configure(applicationId:)를 먼저 호출하세요."
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
            end: activity.timestamps.end
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

