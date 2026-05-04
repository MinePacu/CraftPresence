import Foundation

#if os(macOS)
import AppKit

@MainActor
final class LSUIElementController: NSObject {
    static let shared = LSUIElementController()

    func enableMenuBarOnly() {}
    func disableMenuBarOnly() {}
    func refreshLocalizedMenu() {}
}
#endif
