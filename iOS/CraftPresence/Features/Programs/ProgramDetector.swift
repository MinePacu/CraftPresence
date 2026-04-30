import Combine
import Foundation

public struct ProgramUpdate: Sendable {
    public let appName: String?
    public let bundleID: String?
    public let windowTitle: String?
}

public protocol ProgramDetectorDelegate: AnyObject {
    func programDetector(_ detector: ProgramDetector, didUpdateActiveAppName appName: String?, bundleIdentifier: String?, windowTitle: String?)
}

public final class ProgramDetector: ObservableObject {
    public static let shared = ProgramDetector()

    @MainActor @Published public private(set) var activeAppName: String?
    @MainActor @Published public private(set) var activeBundleIdentifier: String?
    @MainActor @Published public private(set) var activeWindowTitle: String?

    public weak var delegate: ProgramDetectorDelegate?

    private init() {}

    public func start() {
        Task { @MainActor in
            activeAppName = nil
            activeBundleIdentifier = nil
            activeWindowTitle = nil
        }
    }

    public func stop() {}

    public func setPollingInterval(_ interval: TimeInterval) {}

    public func updatesStream() -> AsyncStream<ProgramUpdate> {
        AsyncStream { continuation in
            continuation.yield(ProgramUpdate(appName: nil, bundleID: nil, windowTitle: nil))
            continuation.finish()
        }
    }
}
