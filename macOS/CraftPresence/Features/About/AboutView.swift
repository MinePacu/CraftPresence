import SwiftUI
#if os(macOS)
import ApplicationServices
#endif

struct AboutView: View {
    let activeAppName: String?
    let activeWindowTitle: String?
    let activeBundleID: String?
    @EnvironmentObject private var localizationManager: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("about.title"), systemImage: "info.circle")
                .font(.title2).bold()

            Group {
                InfoRow(label: t("about.app_name"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? t("common.unknown"))
                InfoRow(label: t("about.version"), value: {
                    let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    let b = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
                    switch (v, b) { case let (v?, b?): return "\(v) (\(b))"; case let (v?, nil): return v; case let (nil, b?): return b; default: return t("common.unknown") }
                }())
                InfoRow(label: t("about.bundle_id"), value: Bundle.main.bundleIdentifier ?? t("common.unknown"))
                InfoRow(label: t("about.executable_path"), value: Bundle.main.executableURL?.path(percentEncoded: false) ?? "-")
                #if os(macOS)
                InfoRow(label: t("about.accessibility_permission"), value: AXIsProcessTrusted() ? t("common.granted") : t("common.not_granted"))
                #endif
            }

            Divider().padding(.vertical, 4)

            Group {
                Label {
                    HStack(spacing: 0) {
                        Text("\(t("about.foreground_app")): ")
                        Text(activeAppName ?? t("common.unknown")).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "macwindow") }
                Label {
                    HStack(spacing: 0) {
                        Text("\(t("about.window_title")): ")
                        Text(activeWindowTitle ?? t("common.unknown")).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "text.quote") }
                Label {
                    HStack(spacing: 0) {
                        Text("\(t("about.bundle_id")): ")
                        Text(activeBundleID ?? t("common.unknown")).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "barcode.viewfinder") }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.headline)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    AboutView(activeAppName: "Xcode", activeWindowTitle: "MyProject – ContentView.swift", activeBundleID: "com.apple.dt.Xcode")
}
