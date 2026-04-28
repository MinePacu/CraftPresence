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
struct CraftPresenceApp: App {
    @ObservedObject private var permissionsService = PermissionsService()
    
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
            .onAppear(perform: self.permissionsService.pollAccessibilityPrivileges)
            .onAppear {
                configureDiscordSDK()
                hideTitleBarOnCatalyst()
            }
        }
        .modelContainer(sharedModelContainer)
    }
    
    func hideTitleBarOnCatalyst() {
#if targetEnvironment(macCatalyst)
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.titlebar?.titleVisibility = .hidden
#endif
    }
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        hideTitleBar()
        PermissionsService.acquireAccessibilityPrivileges()
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

    func hideTitleBar() {
        guard let window = NSApplication.shared.windows.first else { assertionFailure(); return }
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}
#endif
