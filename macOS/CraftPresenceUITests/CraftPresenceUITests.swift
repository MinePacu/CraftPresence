//
//  CraftPresenceUITests.swift
//  CraftPresenceUITests
//
//  Created by 노현수 on 10/31/25.
//

import XCTest

final class CraftPresenceUITests: XCTestCase {
    private var settingsPath: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        settingsPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("settings.json")
            .path
    }

    override func tearDownWithError() throws {
        if let settingsPath {
            let settingsURL = URL(fileURLWithPath: settingsPath)
            try? FileManager.default.removeItem(at: settingsURL.deletingLastPathComponent())
        }
    }

    @MainActor
    func testOverviewDisplaysInjectedAutomationState() throws {
        let app = makeApplication()
        app.launchEnvironment["CRAFTPRESENCE_ACTIVE_APP_NAME"] = "Xcode"
        app.launchEnvironment["CRAFTPRESENCE_ACTIVE_BUNDLE_ID"] = "com.apple.dt.Xcode"
        app.launchEnvironment["CRAFTPRESENCE_ACTIVE_WINDOW_TITLE"] = "CraftPresence.xcodeproj"
        app.launch()

        XCTAssertTrue(app.staticTexts["overview.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Xcode"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["com.apple.dt.Xcode"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["CraftPresence.xcodeproj"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testProgramsDisplaysSeededBundleIDs() throws {
        let app = makeApplication()
        app.launchEnvironment["CRAFTPRESENCE_SEED_BUNDLE_IDS"] = "com.apple.Music,com.apple.dt.Xcode"
        app.launch()

        let programsRow = element(in: app, identifier: "sidebar.programs")
        XCTAssertTrue(programsRow.waitForExistence(timeout: 5))
        programsRow.click()

        XCTAssertTrue(app.staticTexts["programs.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["com.apple.Music"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["com.apple.dt.Xcode"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testToolbarSettingsOpensSettingsWindowInsteadOfSheet() throws {
        let app = makeApplication()
        app.launch()

        let settingsButton = app.buttons["toolbar.settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        XCTAssertFalse(app.sheets.firstMatch.waitForExistence(timeout: 1))
        XCTAssertTrue(app.windows.containing(.any, identifier: "settings.root").firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            makeApplication().launch()
        }
    }

    private func makeApplication() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CRAFTPRESENCE_UI_TEST_MODE"] = "1"
        app.launchEnvironment["CRAFTPRESENCE_ACCESSIBILITY_TRUSTED"] = "1"
        app.launchEnvironment["CRAFTPRESENCE_DISABLE_PROGRAM_DETECTOR"] = "1"
        app.launchEnvironment["CRAFTPRESENCE_SETTINGS_PATH"] = settingsPath
        return app
    }

    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
