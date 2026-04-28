import AppKit
import Combine

public struct ProgramUpdate: Sendable {
    public let appName: String?
    public let bundleID: String?
    public let windowTitle: String?
}

public protocol ProgramDetectorDelegate: AnyObject {
    func programDetector(_ detector: ProgramDetector, didUpdateActiveAppName appName: String?, bundleIdentifier: String?, windowTitle: String?)
}

public final class ProgramDetector: NSObject {
    public static let shared = ProgramDetector()

    // Published properties for SwiftUI/Combine consumers
    @MainActor @Published public private(set) var activeAppName: String?
    @MainActor @Published public private(set) var activeBundleIdentifier: String?
    @MainActor @Published public private(set) var activeWindowTitle: String?

    public weak var delegate: ProgramDetectorDelegate?

    private let continuationStore = ProgramContinuationStore()

    private var workspaceObserver: Any?
    private var axObserver: AXObserver?
    private var observedAppElement: AXUIElement?
    private let axQueue = DispatchQueue(label: "ProgramDetector.AXQueue")

    // Polling fallback to catch title changes that don't fire AX notifications
    // Configurable polling interval (default to low-impbrew install codexact)
    private var pollingInterval: TimeInterval = 2.0
    
    private var titleRetryCount: Int = 0
    private let maxTitleRetry: Int = 5

    /// Optionally allow callers to adjust polling interval (in seconds). Values below 0.2 are clamped to 0.2.
    public func setPollingInterval(_ interval: TimeInterval) {
        let clamped = max(0.2, interval)
        pollingInterval = clamped
        if pollingTimer != nil { // if running, restart with new interval
            startPolling()
        }
    }

    private var pollingTimer: Timer?

    private override init() {
        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - Public control

    public func start() {
        // logging disabled
        guard workspaceObserver == nil else { return }

        // Observe when the active app changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let runningApp = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self.handleActivated(app: runningApp)
        }

        // Initialize with current frontmost app
        handleActivated(app: NSWorkspace.shared.frontmostApplication)

        // Start fast polling briefly, then revert to normal interval
        startPolling(interval: 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self else { return }
            self.startPolling()
        }
    }

    public func stop() {
        // logging disabled
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
            self.workspaceObserver = nil
        }
        stopAXObserver()
        stopPolling()
    }
    
    // MARK: - AsyncStream API
    public func updatesStream() -> AsyncStream<ProgramUpdate> {
        AsyncStream { continuation in
            let id = UUID()
            // yield the latest snapshot immediately
            Task { @MainActor in
                let initial = ProgramUpdate(appName: self.activeAppName,
                                            bundleID: self.activeBundleIdentifier,
                                            windowTitle: self.activeWindowTitle)
                continuation.yield(initial)
            }
            Task {
                await self.continuationStore.insert(continuation, for: id)
            }

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.continuationStore.removeValue(for: id)
                }
            }
        }
    }

    // MARK: - Internal

    private func handleActivated(app: NSRunningApplication?) {
        let appName = app?.localizedName
        let bundleID = app?.bundleIdentifier
        let pid = app?.processIdentifier
        // Removed debug print

        Task { @MainActor in
            self.activeAppName = appName
            self.activeBundleIdentifier = bundleID
            self.broadcastUpdate()
        }

        // Rebuild AX observer for the new app
        setupAXObserver(for: pid)

        // Immediately refresh window title (delayed slightly to reduce race conditions)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.refreshWindowTitle(forPID: pid)
        }
    }

    private func setupAXObserver(for pid: pid_t?) {
        stopAXObserver()
        guard let pid else { return }
        // Removed debug print
        // logging disabled
        let appElement = AXUIElementCreateApplication(pid)
        self.observedAppElement = appElement

        var observer: AXObserver?
        let status = AXObserverCreate(pid, ProgramDetector.axObserverCallback, &observer)
        // logging disabled
        guard status == .success, let axObserver = observer else { return }
        self.axObserver = axObserver

        // Observe focused window/title changes, pass self via refcon
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        AXObserverAddNotification(axObserver, appElement, kAXFocusedWindowChangedNotification as CFString, refcon)
        AXObserverAddNotification(axObserver, appElement, kAXTitleChangedNotification as CFString, refcon)

        // Add the observer's run loop source to the main run loop
        let source: CFRunLoopSource = AXObserverGetRunLoopSource(axObserver)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }
    
    private static let axObserverCallback: AXObserverCallback = { (observer, axElement, notification, refcon) in
        // Debug callback entry
        // print("[ProgramDetector] axObserverCallback notification=\(notification)")
        guard let refcon else { return }
        let detector = Unmanaged<ProgramDetector>.fromOpaque(refcon).takeUnretainedValue()
        detector.handleAXNotification(element: axElement, notification: notification)
    }

    private func stopAXObserver() {
        if let axObserver {
            if let element = observedAppElement {
                let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
                AXObserverRemoveNotification(axObserver, element, kAXFocusedWindowChangedNotification as CFString)
                AXObserverRemoveNotification(axObserver, element, kAXTitleChangedNotification as CFString)
                _ = refcon // keep symmetry; no action needed on removal
            }
            self.axObserver = nil
        }
        self.observedAppElement = nil
    }

    private func handleAXNotification(element: AXUIElement, notification: CFString) {
        let pid = currentObservedPID()
        // print("[ProgramDetector] AX notification: \(notification) pid=\(String(describing: pid))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.refreshWindowTitle(forPID: pid)
        }
    }

    private func currentObservedPID() -> pid_t? {
        guard let element = observedAppElement else { return nil }
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        return pid
    }

    private func firstStandardWindow(from windows: [AXUIElement]) -> AXUIElement? {
        for w in windows {
            var roleValue: CFTypeRef?
            let roleRes = AXUIElementCopyAttributeValue(w, kAXRoleAttribute as CFString, &roleValue)
            let role = roleRes == .success ? (roleValue as? String) : nil

            var subroleValue: CFTypeRef?
            let subroleRes = AXUIElementCopyAttributeValue(w, kAXSubroleAttribute as CFString, &subroleValue)
            let subrole = subroleRes == .success ? (subroleValue as? String) : nil

            if role == (kAXWindowRole as String), subrole == (kAXStandardWindowSubrole as String) {
                return w
            }
        }
        return windows.first
    }
    
    private func titleLikeString(for window: AXUIElement) -> String? {
        var titleValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
           let t = titleValue as? String, !t.isEmpty {
            return t
        }
        var descValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXDescriptionAttribute as CFString, &descValue) == .success,
           let d = descValue as? String, !d.isEmpty {
            return d
        }
        var idValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXIdentifierAttribute as CFString, &idValue) == .success,
           let i = idValue as? String, !i.isEmpty {
            return i
        }
        return nil
    }
    
    private func firstWindowWithNonEmptyTitle(from windows: [AXUIElement]) -> (AXUIElement, String)? {
        for w in windows {
            if let t = titleLikeString(for: w) {
                return (w, t)
            }
        }
        return nil
    }

    private func refreshWindowTitle(forPID pid: pid_t?) {
        // Attempt to refresh window title
        guard let pid else {
            updateWindowTitle(nil)
            titleRetryCount = 0
            return
        }
        let appElement = AXUIElementCreateApplication(pid)

        // Get focused window
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value)
        guard result == .success, let windowElement = value as! AXUIElement? else {
            // Removed debug print
            // Fallback: try kAXWindows list
            var windowsValue: CFTypeRef?
            let windowsResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

            // print fallback windows count for diagnostics
            // if let windows = windowsValue as? [AXUIElement] { print("[ProgramDetector] windows fallback count=\(windows.count)") }
            
            if windowsResult == .success, let windows = windowsValue as? [AXUIElement] {
                // if let windows = windowsValue as? [AXUIElement] { print("[ProgramDetector] windows fallback count=\(windows.count)") }
                if let candidate = firstStandardWindow(from: windows), let t = titleLikeString(for: candidate) {
                    titleRetryCount = 0
                    updateWindowTitle(t)
                    return
                }
                if let (_, t) = firstWindowWithNonEmptyTitle(from: windows) {
                    titleRetryCount = 0
                    updateWindowTitle(t)
                    return
                }
            }

            if titleRetryCount < maxTitleRetry {
                titleRetryCount += 1
                let delay = 0.2 + Double(titleRetryCount) * 0.1 // 0.3, 0.4, 0.5, ...
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.refreshWindowTitle(forPID: pid)
                }
            } else {
                titleRetryCount = 0
                updateWindowTitle(nil)
            }
            return
        }

        // Reset retry count on success
        titleRetryCount = 0

        // Get window title
        var titleValue: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleValue)
        if titleResult == .success, let title = titleValue as? String {
            updateWindowTitle(title)
        } else {
            // Removed debug print
            updateWindowTitle(nil)
        }
    }

    private func updateWindowTitle(_ title: String?) {
        Task { @MainActor in
            // print("[ProgramDetector] updateWindowTitle -> \(title ?? "nil")")
            self.activeWindowTitle = title
            self.broadcastUpdate()
            self.delegate?.programDetector(self, didUpdateActiveAppName: self.activeAppName, bundleIdentifier: self.activeBundleIdentifier, windowTitle: title)
        }
    }
    
    private func broadcastUpdate() {
        Task { @MainActor in
            let update = ProgramUpdate(appName: self.activeAppName,
                                       bundleID: self.activeBundleIdentifier,
                                       windowTitle: self.activeWindowTitle)
            let values = await self.continuationStore.values()
            for c in values {
                c.yield(update)
            }
        }
    }

    // MARK: - Polling fallback

    private func startPolling() {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refreshWindowTitle(forPID: self.currentObservedPID())
        }
    }
    private func startPolling(interval: TimeInterval) {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refreshWindowTitle(forPID: self.currentObservedPID())
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
}


// MARK: - Accessibility permission helper
public enum AccessibilityPermission {
    public static func ensureEnabled(promptIfNeeded: Bool = true) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: promptIfNeeded as CFBoolean]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}

private actor ProgramContinuationStore {
    private var continuations = [UUID: AsyncStream<ProgramUpdate>.Continuation]()

    func insert(_ continuation: AsyncStream<ProgramUpdate>.Continuation, for id: UUID) {
        continuations[id] = continuation
    }

    func removeValue(for id: UUID) {
        continuations.removeValue(forKey: id)
    }

    func values() -> [AsyncStream<ProgramUpdate>.Continuation] {
        Array(continuations.values)
    }
}
