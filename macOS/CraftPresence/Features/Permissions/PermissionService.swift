//
//  PermissionService.swift
//  CraftPresence

import Cocoa
import Combine

@MainActor
/// Tracks accessibility trust state and triggers the macOS permission flow when needed.
final class PermissionsService: ObservableObject {
    // Store the active trust state of the app.
    @Published var isTrusted: Bool = PermissionsService.currentTrustState()

    private var pollingTask: Task<Void, Never>?

    // Poll the accessibility state every 1 second to check
    //  and update the trust status.
    /// Starts a lightweight polling loop that refreshes the trust state until accessibility access is granted.
    func pollAccessibilityPrivileges() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                self.isTrusted = AXIsProcessTrusted()
                if self.isTrusted {
                    self.pollingTask = nil
                    return
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    /// Refreshes the current accessibility authorization state and optionally asks macOS to show the prompt.
    func refreshAccessibilityPrivileges(promptIfNeeded: Bool) {
        if AutomationLaunchOptions.isUITesting, AutomationLaunchOptions.isAccessibilityTrusted {
            isTrusted = true
            pollingTask?.cancel()
            pollingTask = nil
            return
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptIfNeeded] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)

        if !isTrusted {
            pollAccessibilityPrivileges()
        } else {
            pollingTask?.cancel()
            pollingTask = nil
        }
    }

    // Request accessibility permissions, this should prompt
    //  macOS to open and present the required dialogue open
    //  to the correct page for the user to just hit the add
    //  button.
    /// Requests accessibility privileges by invoking the system trust check with prompting enabled.
    static func acquireAccessibilityPrivileges() {
        guard !(AutomationLaunchOptions.isUITesting && AutomationLaunchOptions.isAccessibilityTrusted) else {
            return
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private static func currentTrustState() -> Bool {
        if AutomationLaunchOptions.isUITesting, AutomationLaunchOptions.isAccessibilityTrusted {
            return true
        }

        return AXIsProcessTrusted()
    }
}
