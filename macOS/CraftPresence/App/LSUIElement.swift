//
//  LSUIElement.swift
//  CraftPresence
//
//  Created by 노현수 on 11/27/25.
//

import Foundation
#if os(macOS)
import AppKit
#endif

#if os(macOS)
@MainActor
final class LSUIElementController {
    static let shared = LSUIElementController()

    private var statusItem: NSStatusItem?
    private var isEnabled = false

    private init() {}

    /// 메뉴 막대(상태바) 아이콘만 보이도록 전환하고, Dock 아이콘을 숨깁니다.
    /// - Note: 이미 활성화되어 있으면 재진입하지 않습니다.
    func enableMenuBarOnly() {
        guard !isEnabled else { return }
        isEnabled = true

        // 1) Dock 숨김: accessory 정책을 사용하면 Dock 아이콘과 App Switcher에서 사라지고,
        //    상태바 아이콘과 윈도우는 사용할 수 있습니다.
        NSApp.setActivationPolicy(.accessory)

        // 2) 상태바 아이템 생성
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem = item

            // 버튼 구성 (이미지 에셋이 없다면 심볼 또는 텍스트 사용)
            if let button = item.button {
                if #available(macOS 11.0, *) {
                    let image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "CraftPresence")
                    image?.isTemplate = true
                    button.image = image
                } else {
                    button.title = "CP"
                }
                button.toolTip = "CraftPresence"
            }

            // 3) 메뉴 구성
            item.menu = makeMenu()
        }
    }

    /// 메뉴 막대 아이템 제거 및 Dock 복귀
    func disableMenuBarOnly() {
        guard isEnabled else { return }
        isEnabled = false

        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }

        // Dock 복귀
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func refreshLocalizedMenu() {
        guard let item = statusItem else { return }
        item.menu = makeMenu()
    }

    // MARK: - Menu Actions

    @objc private func showMainWindow() {
        // SwiftUI 기반 앱의 메인 윈도우를 전면으로 가져옵니다.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // 첫 번째 윈도우를 보이도록 시도 (필요 시 구체적인 윈도우 관리 로직으로 교체)
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func openPreferences() {
        // 환경설정 화면을 보여주고 싶다면 여기서 구현하세요.
        // 예: 특정 SwiftUI 뷰를 새로운 NSWindow로 띄우는 코드 등
        // 현재는 메인 윈도우를 전면으로 가져오는 기본 동작만 수행
        showMainWindow()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: t("menu.open"), action: #selector(showMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let prefsItem = NSMenuItem(title: t("menu.preferences"), action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: t("menu.quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func t(_ key: String) -> String {
        LocalizationManager.shared.string(key)
    }
}
#endif
