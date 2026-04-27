//
//  SettingView.swift
//  CraftPresence
//
//  Created by Assistant on 2025-11-12.
//

import SwiftUI

struct SettingView: View {
    // Persist toggles with AppStorage so they survive restarts
    @AppStorage("debugLoggingEnabled") private var debugLoggingEnabled: Bool = false
    @AppStorage("menuBarOnlyEnabled") private var menuBarOnlyEnabled: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("일반")) {
                    Toggle(isOn: $menuBarOnlyEnabled.onChange(menuBarToggleChanged)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("메뉴 막대(아이콘) 전용 모드")
                            Text("Dock 아이콘을 숨기고 메뉴 막대 아이콘으로만 동작합니다.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .help("활성화 시 Dock과 앱 전환기에서 숨겨지고, 상태바 아이콘 메뉴로만 조작합니다.")
                }

                #if DEBUG
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
                #endif
            }
            .navigationTitle("설정")
            .onAppear {
                // 설정 화면 진입 시 현재 저장된 상태를 보장 적용
                applyMenuBarMode(menuBarOnlyEnabled)
            }
        }
    }

    private func menuBarToggleChanged(_ newValue: Bool) {
        applyMenuBarMode(newValue)
    }

    private func applyMenuBarMode(_ enabled: Bool) {
        #if os(macOS)
        if enabled {
            LSUIElementController.shared.enableMenuBarOnly()
        } else {
            LSUIElementController.shared.disableMenuBarOnly()
        }
        #endif
    }
}

// MARK: - Binding helper
private extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: { newValue in
                wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}

#Preview {
    SettingView()
}
