//
//  CraftPresenceApp.swift
//  CraftPresence
//
//  Created by 노현수 on 10/31/25.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

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
                hideTitleBarOnCatalyst()
                
                let execPath = Bundle.main.executableURL?.path ?? "(unknown)"
                let cwd = FileManager.default.currentDirectoryPath
                print("[CraftPresence] Executable path: \(execPath)")
                print("[CraftPresence] Current working directory: \(cwd)")
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
    }

    func hideTitleBar() {
        guard let window = NSApplication.shared.windows.first else { assertionFailure(); return }
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}
#endif
