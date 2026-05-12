//
//  CraftPresenceApp.swift
//  CraftPresence

import SwiftUI
import SwiftData
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
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    #endif
    
    /// Shared SwiftData container used by the app scene.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

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
        // Initialize Discord SDK with Application ID
        DiscordSDK.shared.configure(applicationID: appID)
        print("[DiscordSDK] SDK configured")
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
                hideTitleBarOnCatalyst()
                updateDiscordOnboardingPresentation()
            }
            #if os(macOS)
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                permissionsService.refreshAccessibilityPrivileges(promptIfNeeded: false)
                Task {
                    await PresencePriorityController.shared.enforceAppliedPresenceIfNeeded()
                }
            }
            #endif
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
            .environmentObject(permissionsService)
            .environment(\.locale, localizationManager.locale)
            .environmentObject(discordManager)
        }
        .modelContainer(sharedModelContainer)

        #if os(macOS)
        Settings {
            SettingView()
                .environmentObject(localizationManager)
                .environment(\.locale, localizationManager.locale)
        }
        #endif
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
            PresencePriorityController.shared.start()
            print("[DiscordSDK] SDK configured (macOS)")
        }
    }
}
#endif
