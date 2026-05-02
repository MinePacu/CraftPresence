//
//  CraftPresenceUITests.swift
//  CraftPresenceUITests
//
//  Created by Nohyunsoo on 4/30/26.
//

import XCTest

final class CraftPresenceUITests: XCTestCase {
    private var settingsURL: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        settingsURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CraftPresenceUITests-\(UUID().uuidString)")
            .appendingPathComponent("settings.json")
    }

    override func tearDownWithError() throws {
        if let settingsURL {
            try? FileManager.default.removeItem(at: settingsURL.deletingLastPathComponent())
        }
    }

    @MainActor
    func testCustomPresenceScreenShowsEditorAndPrimaryActions() throws {
        let app = launchApp()

        openCustomPresence(in: app)

        XCTAssertTrue(app.descendants(matching: .any)["customPresence.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["presenceForm.title"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["presenceForm.details"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["presenceForm.state"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["presenceForm.partyEnabled"].exists)
        XCTAssertTrue(app.buttons["customPresence.publish"].exists)
        XCTAssertTrue(app.buttons["customPresence.saveAsPreset"].exists)
        XCTAssertTrue(app.buttons["customPresence.clear"].exists)
        XCTAssertTrue(app.buttons["customPresence.reset"].exists)
    }

    @MainActor
    func testCustomPresenceCanBeSavedAsPreset() throws {
        let app = launchApp()

        openCustomPresence(in: app)
        app.descendants(matching: .any)["presenceForm.title"].clearAndTypeText("UI Test Presence")
        app.descendants(matching: .any)["presenceForm.details"].tapAndTypeText("Testing the custom editor")
        app.descendants(matching: .any)["presenceForm.state"].tapAndTypeText("Ready to save")

        app.buttons["customPresence.saveAsPreset"].tap()
        XCTAssertTrue(app.staticTexts["Preset saved."].waitForExistence(timeout: 5))

        openPresets(in: app)
        XCTAssertTrue(app.staticTexts["UI Test Presence"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Testing the custom editor"].exists)
        XCTAssertTrue(app.staticTexts["Ready to save"].exists)
    }

    @MainActor
    func testCustomPresenceRestoresLastSavedDraftAfterRelaunch() throws {
        let app = launchApp()

        openCustomPresence(in: app)
        app.descendants(matching: .any)["presenceForm.title"].clearAndTypeText("Restored Presence")
        app.descendants(matching: .any)["presenceForm.details"].tapAndTypeText("Loaded after relaunch")
        app.descendants(matching: .any)["presenceForm.state"].tapAndTypeText("Still here")
        app.buttons["customPresence.saveAsPreset"].tap()
        XCTAssertTrue(app.staticTexts["Preset saved."].waitForExistence(timeout: 5))

        app.terminate()
        let relaunchedApp = launchApp()
        openCustomPresence(in: relaunchedApp)

        XCTAssertTrue(relaunchedApp.staticTexts["Restored Presence"].waitForExistence(timeout: 5))
        XCTAssertTrue(relaunchedApp.staticTexts["Loaded after relaunch"].exists)
        XCTAssertTrue(relaunchedApp.staticTexts["Still here"].exists)
    }

    @MainActor
    func testOverviewShowsLatestCustomPresenceDraft() throws {
        let app = launchApp()

        openCustomPresence(in: app)
        app.descendants(matching: .any)["presenceForm.title"].clearAndTypeText("Overview Presence")
        app.descendants(matching: .any)["presenceForm.details"].tapAndTypeText("Visible from overview")
        app.descendants(matching: .any)["presenceForm.state"].tapAndTypeText("Synced state")
        app.buttons["customPresence.saveAsPreset"].tap()
        XCTAssertTrue(app.staticTexts["Preset saved."].waitForExistence(timeout: 5))

        openOverview(in: app)

        XCTAssertTrue(app.staticTexts["Overview Presence"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Visible from overview"].exists)
        XCTAssertTrue(app.staticTexts["Synced state"].exists)
        XCTAssertTrue(app.staticTexts["Elapsed time"].exists)
        XCTAssertTrue(app.staticTexts["No start time"].exists)
    }

    @MainActor
    func testCustomPresenceResetRestoresDefaultDraft() throws {
        let app = launchApp()

        openCustomPresence(in: app)
        app.descendants(matching: .any)["presenceForm.title"].clearAndTypeText("Temporary Presence")

        app.buttons["customPresence.reset"].tap()

        XCTAssertTrue(app.staticTexts["Presence draft reset."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Custom Presence"].exists)
        XCTAssertFalse(app.staticTexts["Temporary Presence"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            launchApp()
        }
    }

    @discardableResult
    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CRAFTPRESENCE_UI_TEST_MODE"] = "1"
        app.launchEnvironment["CRAFTPRESENCE_DISABLE_PROGRAM_DETECTOR"] = "1"
        app.launchEnvironment["CRAFTPRESENCE_SETTINGS_PATH"] = settingsURL.path
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()
        return app
    }

    @MainActor
    private func openCustomPresence(in app: XCUIApplication) {
        tapNavigationItem("sidebar.customPresence", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["customPresence.title"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openPresets(in app: XCUIApplication) {
        tapNavigationItem("sidebar.programs", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["programs.title"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openOverview(in app: XCUIApplication) {
        tapNavigationItem("sidebar.overview", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["overview.title"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func tapNavigationItem(_ identifier: String, in app: XCUIApplication) {
        var match = app.descendants(matching: .any)[identifier]
        var attempts = 0
        while !match.exists && attempts < 3 {
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            guard backButton.exists else { break }
            backButton.tap()
            attempts += 1
            match = app.descendants(matching: .any)[identifier]
        }
        XCTAssertTrue(match.waitForExistence(timeout: 5), "Expected navigation item \(identifier) to exist.")
        match.tap()
    }
}

private extension XCUIElement {
    func clearAndTypeText(_ text: String) {
        tap()
        if let value = value as? String, !value.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
            typeText(deleteString)
        }
        typeText(text)
    }

    func tapAndTypeText(_ text: String) {
        tap()
        typeText(text)
    }
}
