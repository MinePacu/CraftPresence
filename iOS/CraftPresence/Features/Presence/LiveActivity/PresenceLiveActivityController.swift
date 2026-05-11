import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class PresenceLiveActivityController {
    static let shared = PresenceLiveActivityController()

    private init() {}

    func restoreAppliedPresence(connectionStatus: String) async {
        guard let appliedPresence = await ConfigUtility.shared.currentAppliedPresence() else {
            return
        }

        await publish(appliedPresence, connectionStatus: connectionStatus)
    }

    func publish(_ preset: CustomPresencePreset, connectionStatus: String) async {
        let payload = AppliedPresencePayload(customPresencePreset: preset)
        await publish(payload, connectionStatus: connectionStatus)
    }

    func publish(_ payload: AppliedPresencePayload, connectionStatus: String) async {
        guard await ConfigUtility.shared.isPresenceLiveActivityEnabled() else {
            await end()
            return
        }

        #if canImport(ActivityKit)
        guard #available(iOS 16.2, *), ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        let contentOptions = await ConfigUtility.shared.liveActivityContentOptions()
        let state = PresenceLiveActivityContentBuilder.contentState(
            for: payload,
            connectionStatus: connectionStatus,
            isLive: true,
            contentOptions: contentOptions
        )
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
                isLive: false,
                contentOptions: LiveActivityContentOptions()
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

    #endif
}

#if canImport(ActivityKit)
enum PresenceLiveActivityContentBuilder {
    @available(iOS 16.2, *)
    static func contentState(
        for payload: AppliedPresencePayload,
        connectionStatus: String,
        isLive: Bool,
        contentOptions: LiveActivityContentOptions
    ) -> PresenceActivityAttributes.ContentState {
        return PresenceActivityAttributes.ContentState(
            title: payload.name.nilIfEmpty ?? "CraftPresence",
            details: payload.details?.nilIfEmpty,
            state: payload.state?.nilIfEmpty,
            connectionStatus: connectionStatus,
            startedAt: contentOptions.elapsedTime ? payload.start : nil,
            isLive: isLive,
            contentOptions: contentOptions
        )
    }
}
#endif

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
