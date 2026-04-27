import SwiftUI
#if os(macOS)
import ApplicationServices
#endif

struct AboutView: View {
    let activeAppName: String?
    let activeWindowTitle: String?
    let activeBundleID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("About", systemImage: "info.circle")
                .font(.title2).bold()

            Group {
                InfoRow(label: "App Name", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Unknown")
                InfoRow(label: "Version", value: {
                    let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    let b = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
                    switch (v, b) { case let (v?, b?): return "\(v) (\(b))"; case let (v?, nil): return v; case let (nil, b?): return b; default: return "Unknown" }
                }())
                InfoRow(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown")
                InfoRow(label: "Executable Path", value: Bundle.main.executableURL?.path(percentEncoded: false) ?? "-")
                #if os(macOS)
                InfoRow(label: "Accessibility Permission", value: AXIsProcessTrusted() ? "Granted" : "Not Granted")
                #endif
            }

            Divider().padding(.vertical, 4)

            Group {
                Label {
                    HStack(spacing: 0) {
                        Text("현재 포그라운드 창: ")
                        Text(activeAppName ?? "알 수 없음").foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "macwindow") }
                Label {
                    HStack(spacing: 0) {
                        Text("창 타이틀: ")
                        Text(activeWindowTitle ?? "알 수 없음").foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "text.quote") }
                Label {
                    HStack(spacing: 0) {
                        Text("Bundle ID: ")
                        Text(activeBundleID ?? "알 수 없음").foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: "barcode.viewfinder") }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
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
