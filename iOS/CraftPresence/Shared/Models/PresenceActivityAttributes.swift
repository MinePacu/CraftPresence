import Foundation

public struct LiveActivityContentOptions: Codable, Hashable, Sendable {
    public var presenceSummary: Bool
    public var elapsedTime: Bool
    public var discordStatus: Bool

    nonisolated public init(
        presenceSummary: Bool = true,
        elapsedTime: Bool = true,
        discordStatus: Bool = true
    ) {
        self.presenceSummary = presenceSummary
        self.elapsedTime = elapsedTime
        self.discordStatus = discordStatus
    }
}

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
        var contentOptions: LiveActivityContentOptions

        init(
            title: String,
            details: String?,
            state: String?,
            connectionStatus: String,
            startedAt: Date?,
            isLive: Bool,
            contentOptions: LiveActivityContentOptions = LiveActivityContentOptions()
        ) {
            self.title = title
            self.details = details
            self.state = state
            self.connectionStatus = connectionStatus
            self.startedAt = startedAt
            self.isLive = isLive
            self.contentOptions = contentOptions
        }

        private enum CodingKeys: String, CodingKey {
            case title
            case details
            case state
            case connectionStatus
            case startedAt
            case isLive
            case contentOptions
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.title = try container.decode(String.self, forKey: .title)
            self.details = try container.decodeIfPresent(String.self, forKey: .details)
            self.state = try container.decodeIfPresent(String.self, forKey: .state)
            self.connectionStatus = try container.decode(String.self, forKey: .connectionStatus)
            self.startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
            self.isLive = try container.decode(Bool.self, forKey: .isLive)
            self.contentOptions = try container.decodeIfPresent(
                LiveActivityContentOptions.self,
                forKey: .contentOptions
            ) ?? LiveActivityContentOptions()
        }
    }

    var activityID: String
}
#endif
