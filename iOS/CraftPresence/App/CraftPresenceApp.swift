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
    @State private var discordOnboardingSkippedForLaunch: Bool = false
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
                PresenceScheduleManager.shared.start()
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
                    await PresenceScheduleManager.shared.evaluate()
                    await PresencePriorityController.shared.enforceAppliedPresenceIfNeeded()
                    await restoreAppliedPresenceLiveActivity()
                }
                updateDiscordOnboardingPresentation()
            }
            .onChange(of: permissionsService.isTrusted) { _, _ in
                updateDiscordOnboardingPresentation()
            }
            .onChange(of: discordManager.authorizationStatus) { _, newStatus in
                if newStatus == .authorized {
                    discordOnboardingSkippedForLaunch = false
                }
                updateDiscordOnboardingPresentation()
            }
            .onChange(of: discordManager.dashboardStatus) { _, newStatus in
                if newStatus == .ready {
                    discordOnboardingSkippedForLaunch = false
                }
                updateDiscordOnboardingPresentation()
            }
            .task {
                await seedAutomationSettingsIfNeeded()
                await localizationManager.load()
            }
            .discordOnboardingPresentation(isPresented: $showingDiscordOnboarding) {
                completeDiscordOnboarding()
            } onSkip: {
                skipDiscordOnboardingForLaunch()
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
        #if os(iOS) || targetEnvironment(macCatalyst)
        if isDiscordConnected {
            showingDiscordOnboarding = false
            return
        }

        showingDiscordOnboarding = permissionsService.isTrusted
            && !discordOnboardingSkippedForLaunch
            && !isDiscordConnectionInProgress
            && !AutomationLaunchOptions.isUITesting
        #else
        showingDiscordOnboarding = false
        #endif
    }

    private var isDiscordConnected: Bool {
        discordManager.authorizationStatus == .authorized || discordManager.dashboardStatus == .ready
    }

    private var isDiscordConnectionInProgress: Bool {
        switch discordManager.dashboardStatus {
        case .authorizing, .connecting:
            return true
        case .notConfigured, .configured, .ready, .unauthorized, .failed:
            return false
        }
    }

    private func completeDiscordOnboarding() {
        discordOnboardingSkippedForLaunch = false
        showingDiscordOnboarding = false
    }

    private func skipDiscordOnboardingForLaunch() {
        discordOnboardingSkippedForLaunch = true
        showingDiscordOnboarding = false
    }

    @MainActor
    private func restoreAppliedPresenceLiveActivity() async {
        await PresenceLiveActivityController.shared.restoreAppliedPresence(
            connectionStatus: localizationManager.string(discordManager.dashboardStatus.localizationKey)
        )
    }
}

private struct DiscordOnboardingPresentationModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onFinish: () -> Void
    let onSkip: () -> Void

    func body(content: Content) -> some View {
        #if os(iOS) || targetEnvironment(macCatalyst)
        content
            .fullScreenCover(isPresented: $isPresented) {
                onboardingView
            }
        #else
        content
            .sheet(isPresented: $isPresented) {
                onboardingView
            }
        #endif
    }

    private var onboardingView: some View {
        DiscordConnectionView(mode: .onboarding, onFinish: onFinish, onSkip: onSkip)
            .interactiveDismissDisabled()
            .environmentObject(LocalizationManager.shared)
    }
}

private extension View {
    func discordOnboardingPresentation(
        isPresented: Binding<Bool>,
        onFinish: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) -> some View {
        modifier(
            DiscordOnboardingPresentationModifier(
                isPresented: isPresented,
                onFinish: onFinish,
                onSkip: onSkip
            )
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
