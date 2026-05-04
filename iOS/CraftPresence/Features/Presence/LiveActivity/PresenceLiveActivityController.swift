import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class PresenceLiveActivityController {
    static let shared = PresenceLiveActivityController()

    private init() {}

    func publish(_ preset: CustomPresencePreset, connectionStatus: String) async {
        guard await ConfigUtility.shared.isPresenceLiveActivityEnabled() else {
            await end()
            return
        }

        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let state = contentState(for: preset, connectionStatus: connectionStatus, isLive: true)
        let content = ActivityContent(state: state, staleDate: nil)

        if let activity = currentActivity {
            await activity.update(content)
            return
        }

        do {
            _ = try Activity.request(
                attributes: PresenceActivityAttributes(activityID: "current-presence"),
                content: content,
                pushType: nil
            )
        } catch {
            #if DEBUG
            print("Failed to start Presence Live Activity: \(error)")
            #endif
        }
        #endif
    }

    func end() async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *) else { return }

        for activity in Activity<PresenceActivityAttributes>.activities {
            let endedState = PresenceActivityAttributes.ContentState(
                title: "CraftPresence",
                details: nil,
                state: nil,
                connectionStatus: "Stopped",
                startedAt: nil,
                isLive: false
            )
            await activity.end(
                ActivityContent(state: endedState, staleDate: Date()),
                dismissalPolicy: .immediate
            )
        }
        #endif
    }

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private var currentActivity: Activity<PresenceActivityAttributes>? {
        Activity<PresenceActivityAttributes>.activities.first
    }

    private func contentState(
        for preset: CustomPresencePreset,
        connectionStatus: String,
        isLive: Bool
    ) -> PresenceActivityAttributes.ContentState {
        let normalized = preset.normalized
        return PresenceActivityAttributes.ContentState(
            title: normalized.title.nilIfEmpty ?? "CraftPresence",
            details: normalized.details.nilIfEmpty,
            state: normalized.state.nilIfEmpty,
            connectionStatus: connectionStatus,
            startedAt: normalized.usesElapsedTime ? normalized.elapsedStartDate : nil,
            isLive: isLive
        )
    }
    #endif
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
