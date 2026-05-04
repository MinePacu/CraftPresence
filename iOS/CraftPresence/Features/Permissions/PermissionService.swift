import Combine
import Foundation

@MainActor
final class PermissionsService: ObservableObject {
    @Published var isTrusted: Bool = true

    func pollAccessibilityPrivileges() {
        isTrusted = true
    }

    func refreshAccessibilityPrivileges(promptIfNeeded: Bool) {
        isTrusted = true
    }

    static func acquireAccessibilityPrivileges() {}
}
