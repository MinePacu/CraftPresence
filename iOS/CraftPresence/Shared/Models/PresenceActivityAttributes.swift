import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct PresenceActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var details: String?
        var state: String?
        var connectionStatus: String
        var startedAt: Date?
        var isLive: Bool
    }

    var activityID: String
}
#endif
