//
//  CraftPresenceApp.swift
//  CraftPresence

import SwiftUI
#if os(macOS)
import AppKit
#endif
//import DiscordSDKManager

@main
/// Main application entry point that wires together persistence, permissions, and localization.
struct CraftPresenceApp: App {
    @StateObject private var permissionsService = PermissionsService()
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var discordManager = DiscordSDKManager.shared
    @AppStorage("discordOnboardingCompleted") private var discordOnboardingCompleted: Bool = false
    @State private var showingDiscordOnboarding: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    /// Reads the Discord application identifier from configuration and initializes the SDK where supported.
    private func configureDiscordSDK() {
#if os(iOS) || targetEnvironment(macCatalyst)
        let rawValue = Bundle.main.object(forInfoDictionaryKey: "APPLICATION_ID") as? String
        let appID = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if appID.isEmpty {
            print("[DiscordSDK] APPLICATION_ID not found or empty in Info.plist")
            return
        }
        let masked = appID.count > 6 ? String(appID.prefix(3)) + String(repeating: "*", count: max(0, appID.count - 6)) + String(appID.suffix(3)) : String(repeating: "*", count: appID.count)
        print("[DiscordSDK] Loaded APPLICATION_ID: \(masked)")
        DiscordSDKManager.shared.configure(applicationId: appID, autoAuthorize: false)
        print("[DiscordSDK] SDK manager configured")
#endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if self.permissionsService.isTrusted {
                    ContentView()
                } else {
                    PermissionsView()
                }
            }
            .onAppear {
                #if os(macOS)
                permissionsService.refreshAccessibilityPrivileges(promptIfNeeded: !AutomationLaunchOptions.isUITesting)
                #else
                permissionsService.pollAccessibilityPrivileges()
                #endif
                configureDiscordSDK()
                PresencePriorityController.shared.start()
                Task {
                    await restoreAppliedPresenceLiveActivity()
                }
                hideTitleBarOnCatalyst()
                updateDiscordOnboardingPresentation()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                #if os(macOS)
                permissionsService.refreshAccessibilityPrivileges(promptIfNeeded: false)
                #endif
                Task {
                    await PresencePriorityController.shared.enforceAppliedPresenceIfNeeded()
                    await restoreAppliedPresenceLiveActivity()
                }
            }
            .onChange(of: permissionsService.isTrusted) { _, _ in
                updateDiscordOnboardingPresentation()
            }
            .onChange(of: discordOnboardingCompleted) { _, _ in
                updateDiscordOnboardingPresentation()
            }
            .task {
                await seedAutomationSettingsIfNeeded()
                await localizationManager.load()
            }
            .sheet(isPresented: $showingDiscordOnboarding) {
                DiscordConnectionView(mode: .onboarding) {
                    discordOnboardingCompleted = true
                    showingDiscordOnboarding = false
                }
                .interactiveDismissDisabled()
                .environmentObject(localizationManager)
            }
            .environmentObject(localizationManager)
            .environment(\.locale, localizationManager.locale)
            .environmentObject(discordManager)
        }
    }
    
    /// Hides the default title bar when the app runs as a Mac Catalyst build.
    func hideTitleBarOnCatalyst() {
#if targetEnvironment(macCatalyst)
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.titlebar?.titleVisibility = .hidden
#endif
    }

    /// Seeds deterministic settings for UI automation runs so previews and tests can start from a known state.
    private func seedAutomationSettingsIfNeeded() async {
        guard AutomationLaunchOptions.isUITesting else { return }

        let seededBundleIDs = AutomationLaunchOptions.seedBundleIDs
        guard !seededBundleIDs.isEmpty else { return }

        var settings = await ConfigUtility.shared.currentSettings()
        settings.bundleIDs = seededBundleIDs.sorted()

        do {
            _ = try await ConfigUtility.shared.setSettings(settings)
        } catch {
            #if DEBUG
            print("Failed to seed automation settings: \(error)")
            #endif
        }
    }

    private func updateDiscordOnboardingPresentation() {
        showingDiscordOnboarding = permissionsService.isTrusted
            && !discordOnboardingCompleted
            && !AutomationLaunchOptions.isUITesting
    }

    @MainActor
    private func restoreAppliedPresenceLiveActivity() async {
        await PresenceLiveActivityController.shared.restoreAppliedPresence(
            connectionStatus: localizationManager.string(discordManager.dashboardStatus.localizationKey)
        )
    }
}

#if os(macOS)
/// AppKit delegate responsible for early macOS-only bootstrapping such as accessibility prompts and Discord setup.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AutomationLaunchOptions.isUITesting else { return }

        let rawValue = Bundle.main.object(forInfoDictionaryKey: "APPLICATION_ID") as? String
        let appID = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if appID.isEmpty {
            print("[DiscordSDK] APPLICATION_ID not found or empty in Info.plist (macOS)")
        } else {
            let masked = appID.count > 6 ? String(appID.prefix(3)) + String(repeating: "*", count: max(0, appID.count - 6)) + String(appID.suffix(3)) : String(repeating: "*", count: appID.count)
            print("[DiscordSDK] Loaded APPLICATION_ID (macOS): \(masked)")
            DiscordSDKManager.shared.configure(applicationId: appID,  autoAuthorize: false)
            print("[DiscordSDK] SDK configured (macOS)")
        }
    }
}
#endif
