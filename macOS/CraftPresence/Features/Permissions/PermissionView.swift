//
//  PermissionView.swift
//  CraftPresence

import SwiftUI

/// Onboarding screen shown until the app receives the accessibility permission required for app detection.
struct PermissionsView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var permissionsService: PermissionsService

    /// Opens the macOS Accessibility settings pane so the user can grant the required permission.
    func openSystemPreferences() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(t("permissions.title"))
                .font(.largeTitle.weight(.semibold))

            Text(t("permissions.message"))
                .font(.body)
                .multilineTextAlignment(.center)

            Text(t("permissions.instructions"))
                .font(.body)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button(t("permissions.open_settings"), action: openSystemPreferences)
                    .buttonStyle(.borderedProminent)

                Button(t("permissions.refresh"), action: refreshPermissions)
                    .buttonStyle(.bordered)
            }

            Text(t("permissions.footer"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 35)
    }

    private func refreshPermissions() {
        permissionsService.refreshAccessibilityPrivileges(promptIfNeeded: false)
    }

    private func t(_ key: String) -> String {
        localizationManager.string(key)
    }
}

struct PermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionsView()
            .environmentObject(LocalizationManager.shared)
            .environmentObject(PermissionsService())
    }
}
