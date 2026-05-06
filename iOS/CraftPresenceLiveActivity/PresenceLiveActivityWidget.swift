import ActivityKit
import SwiftUI
import WidgetKit

struct PresenceLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PresenceActivityAttributes.self) { context in
            LockScreenPresenceView(state: context.state)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.accentColor)
                .widgetURL(URL(string: "craftpresence://overview"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveIndicatorView(isLive: context.state.isLive)
                        .padding(.top, 2)
                        .padding(.leading, 6)
                        .frame(minWidth: 44, idealWidth: 52, maxWidth: 60, alignment: .leading)
                        .layoutPriority(2)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedTimeView(startedAt: context.state.startedAt)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.top, 2)
                        .padding(.trailing, 6)
                        .frame(width: 68, alignment: .trailing)
                        .layoutPriority(2)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.title)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                        Text(subtitle(for: context.state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .layoutPriority(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Link(destination: URL(string: "craftpresence://presence/stop")!) {
                        Label("Stop Presence", systemImage: "xmark.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .tint(.red)
                }
            } compactLeading: {
                Image(systemName: context.state.isLive ? "paperplane.fill" : "paperplane")
                    .foregroundStyle(context.state.isLive ? .green : .secondary)
            } compactTrailing: {
                ElapsedTimeView(startedAt: context.state.startedAt)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: context.state.isLive ? "paperplane.fill" : "paperplane")
                    .foregroundStyle(context.state.isLive ? .green : .secondary)
            }
            .widgetURL(URL(string: "craftpresence://overview"))
        }
    }

    private func summary(for state: PresenceActivityAttributes.ContentState) -> String {
        [state.details, state.state]
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed?.isEmpty == false ? trimmed : nil
            }
            .joined(separator: " - ")
    }

    private func subtitle(for state: PresenceActivityAttributes.ContentState) -> String {
        [summary(for: state), state.connectionStatus]
            .compactMap { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            .joined(separator: " - ")
    }
}

private struct LiveIndicatorView: View {
    let isLive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isLive ? Color.green : Color.secondary)
                .frame(width: 5, height: 5)
            Text(isLive ? "Live" : "Off")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isLive ? .green : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct LockScreenPresenceView: View {
    let state: PresenceActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: state.isLive ? "paperplane.fill" : "paperplane")
                .font(.title3.weight(.semibold))
                .foregroundStyle(state.isLive ? .green : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(state.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    ElapsedTimeView(startedAt: state.startedAt)
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text([state.details, state.state].compactMap(\.self).filter { !$0.isEmpty }.joined(separator: " - "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(state.connectionStatus)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ElapsedTimeView: View {
    let startedAt: Date?

    var body: some View {
        Group {
            if let startedAt {
                Text(startedAt, style: .timer)
            } else {
                Text("--:--")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .truncationMode(.tail)
    }
}
