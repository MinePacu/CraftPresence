//
//  PermissionView.swift
//  CraftPresence

import SwiftUI

struct PermissionsView: View {

    func openSystemPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    var body: some View {
        VStack {
            Text("권한 필요 🔐")
                .font(.system(size: 32))
                .padding(.bottom, 25)

            Text("이 앱에는 macOS의 손쉬운 사용(접근성) 권한이 필요합니다.")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .padding(.bottom, 15)

            Text("일반적으로 macOS에서 권한 요청 창이 표시되지만, 표시되지 않았다면 아래 버튼을 눌러 설정으로 이동하세요:")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .padding(.bottom, 25)

            Button("시스템 설정 열기", action: openSystemPreferences)
                .buttonStyle(ThemedButtonStyle(fontSize: 16, width: 220))
                .padding(.bottom, 25)

            Text("권한이 허용되면 몇 초 내로 앱이 자동으로 활성화됩니다.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 35)
    }
}

struct PermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsView()
    }
}

struct ThemedButtonStyle: ButtonStyle {
    let fontSize: CGFloat
    let width: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .frame(width: width, height: 36)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(configuration.isPressed ? 0.7 : 1.0))
            )
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 0)
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.0 : 0.15), radius: 6, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
