import SwiftUI

struct OverviewView: View {
    let activeAppName: String?
    let activeWindowTitle: String?
    let activeBundleID: String?
    let programIDs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("OverView", systemImage: "rectangle.and.text.magnifyingglass")
                .font(.title2).bold()
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
            Label {
                let isTracked = (activeBundleID != nil) && programIDs.contains(activeBundleID!)
                if isTracked {
                    Text("Programs에 등록됨")
                        .foregroundStyle(.green)
                } else {
                    Text("Programs에 미등록")
                        .foregroundStyle(.secondary)
                }
            } icon: { Image(systemName: "checkmark.seal") }
            Label {
                HStack(spacing: 0) {
                    Text("Discord Rich Presence: ")
                    Text("연결되지 않음").foregroundStyle(.secondary)
                }
            } icon: { Image(systemName: "gamecontroller") }
            Spacer()
        }
        .padding(.horizontal, 12)
    }
}

#Preview {
    OverviewView(activeAppName: "Xcode", activeWindowTitle: "MyProject – ContentView.swift", activeBundleID: "com.apple.dt.Xcode", programIDs: ["com.apple.dt.Xcode"])
}
