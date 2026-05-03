import SwiftUI
#if os(macOS)
import ApplicationServices
#endif

struct AboutView: View {
    let activeAppName: String?
    let activeWindowTitle: String?
    let activeBundleID: String?
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        CPSettingsPage {
            CPHeaderCard(
                title: t("about.title"),
                subtitle: Bundle.main.bundleIdentifier ?? t("common.unknown"),
                systemImage: "info.circle",
                tint: .blue
            )

            CPGroupedSection {
                InfoRow(label: t("about.app_name"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? t("common.unknown"), systemImage: "app", tint: .pink)
                CPSectionDivider()
                InfoRow(label: t("about.version"), value: appVersionText, systemImage: "number", tint: .purple)
                CPSectionDivider()
                InfoRow(label: t("about.bundle_id"), value: Bundle.main.bundleIdentifier ?? t("common.unknown"), systemImage: "barcode.viewfinder", tint: .orange)
                CPSectionDivider()
                InfoRow(label: t("about.executable_path"), value: Bundle.main.executableURL?.path(percentEncoded: false) ?? "-", systemImage: "folder", tint: .gray)
                #if os(macOS)
                CPSectionDivider()
                InfoRow(label: t("about.accessibility_permission"), value: AXIsProcessTrusted() ? t("common.granted") : t("common.not_granted"), systemImage: "hand.raised", tint: .green)
                #endif
            }

            CPGroupedSection {
                InfoRow(label: t("about.foreground_app"), value: activeAppName ?? t("common.unknown"), systemImage: "macwindow", tint: .blue)
                CPSectionDivider()
                InfoRow(label: t("about.window_title"), value: activeWindowTitle ?? t("common.unknown"), systemImage: "text.quote", tint: .green)
                CPSectionDivider()
                InfoRow(label: t("about.bundle_id"), value: activeBundleID ?? t("common.unknown"), systemImage: "barcode.viewfinder", tint: .orange)
            }
        }
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }

    private var appVersionText: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let b = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
        switch (v, b) {
        case let (v?, b?):
            return "\(v) (\(b))"
        case let (v?, nil):
            return v
        case let (nil, b?):
            return b
        default:
            return t("common.unknown")
        }
    }

    private var showsInlinePageHeader: Bool {
        horizontalSizeClass != .compact
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        CPSettingsRow(title: label, systemImage: systemImage, tint: tint) {
            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .font(.callout)
        }
    }
}
