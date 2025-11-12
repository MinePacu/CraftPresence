//
//  SettingView.swift
//  CraftPresence
//
//  Created by Assistant on 2025-11-12.
//

import SwiftUI

struct SettingView: View {
    // Persist the toggle so other parts of the app can read it via AppStorage
    @AppStorage("debugLoggingEnabled") private var debugLoggingEnabled: Bool = false

    var body: some View {
        #if DEBUG
        NavigationStack {
            Form {
                Section(header: Text("디버그")) {
                    Toggle(isOn: $debugLoggingEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("디버그 로그 사용")
                            Text("개발/테스트 중에만 사용됩니다. 릴리즈 빌드에서는 무시됩니다.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(footer: Text("이 설정은 디버그 빌드에서만 노출됩니다. 릴리즈 빌드에서는 항상 비활성화됩니다.")) {
                    EmptyView()
                }
            }
            .navigationTitle("설정")
        }
        #else
        // In release builds, show a simple placeholder or other settings if needed
        NavigationStack {
            Form {
                Section {
                    Label("이 빌드는 릴리즈 모드입니다.", systemImage: "lock.fill")
                }
            }
            .navigationTitle("설정")
        }
        #endif
    }
}

#Preview {
    SettingView()
}
