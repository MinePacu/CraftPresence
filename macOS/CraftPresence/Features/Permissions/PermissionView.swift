//
//  PermissionView.swift
//  CraftPresence

import SwiftUI

/// Onboarding screen shown until the app receives the accessibility permission required for app detection.
struct PermissionsView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager

    /// Opens the macOS Accessibility settings pane so the user can grant the required permission.
    func openSystemPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    var body: some View {
        VStack {
            Text(t("permissions.title"))
                .font(.system(size: 32))
                .padding(.bottom, 25)

            Text(t("permissions.message"))
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .padding(.bottom, 15)

            Text(t("permissions.instructions"))
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .padding(.bottom, 25)

            Button(t("permissions.open_settings"), action: openSystemPreferences)
                .buttonStyle(ThemedButtonStyle(fontSize: 16, width: 220))
                .padding(.bottom, 25)

            Text(t("permissions.footer"))
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 35)
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

struct PermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsView()
    }
}

/// Simple branded button style used on the permissions screen.
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
