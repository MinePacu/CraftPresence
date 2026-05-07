//
//  CraftPresenceTests.swift
//  CraftPresenceTests
//
//  Created by Nohyunsoo on 4/30/26.
//

import XCTest
@testable import CraftPresence

final class CraftPresenceTests: XCTestCase {
    func testElapsedStartDateResetsToPublishTimeWhenToggleIsEnabled() {
        let previousStart = Date(timeIntervalSince1970: 1_000)
        let publishTime = Date(timeIntervalSince1970: 2_000)
        let preset = CustomPresencePreset(
            title: "Focus",
            activityType: .playing,
            details: "Deep work",
            state: "Writing",
            usesElapsedTime: true,
            elapsedStartDate: previousStart,
            resetsElapsedTimeOnPublish: true
        )

        XCTAssertEqual(preset.elapsedStartDateForPublish(now: publishTime), publishTime)
    }

    func testElapsedStartDatePreservesExistingTimeWhenToggleIsDisabled() {
        let previousStart = Date(timeIntervalSince1970: 1_000)
        let publishTime = Date(timeIntervalSince1970: 2_000)
        let preset = CustomPresencePreset(
            title: "Focus",
            activityType: .playing,
            details: "Deep work",
            state: "Writing",
            usesElapsedTime: true,
            elapsedStartDate: previousStart,
            resetsElapsedTimeOnPublish: false
        )

        XCTAssertEqual(preset.elapsedStartDateForPublish(now: publishTime), previousStart)
    }

    func testElapsedStartDateIsNilWhenElapsedTimeIsDisabled() {
        let publishTime = Date(timeIntervalSince1970: 2_000)
        let preset = CustomPresencePreset(
            title: "Focus",
            activityType: .playing,
            details: "Deep work",
            state: "Writing",
            usesElapsedTime: false,
            elapsedStartDate: Date(timeIntervalSince1970: 1_000),
            resetsElapsedTimeOnPublish: true
        )

        XCTAssertNil(preset.elapsedStartDateForPublish(now: publishTime))
    }

    func testElapsedStartDateCanPreserveMatchingAppliedPresenceWhenToggleIsDisabled() {
        let previousStart = Date(timeIntervalSince1970: 1_000)
        let publishTime = Date(timeIntervalSince1970: 2_000)
        let appliedPresence = CustomPresencePreset(
            title: "Focus",
            activityType: .playing,
            details: "Deep work",
            state: "Writing",
            usesElapsedTime: true,
            elapsedStartDate: previousStart,
            resetsElapsedTimeOnPublish: false
        )
        let draft = CustomPresencePreset(
            title: "Focus",
            activityType: .playing,
            details: "Deep work",
            state: "Writing",
            usesElapsedTime: true,
            elapsedStartDate: nil,
            resetsElapsedTimeOnPublish: false
        )

        XCTAssertEqual(
            draft.elapsedStartDateForPublish(now: publishTime, preserving: appliedPresence),
            previousStart
        )
    }

    func testAppliedPresencePayloadPreservesCustomPresenceFields() {
        let startDate = Date(timeIntervalSince1970: 1_000)
        let preset = CustomPresencePreset(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: " Focus ",
            activityType: .watching,
            details: " Deep work ",
            state: " Writing ",
            largeImageKey: " focus ",
            largeImageText: " Focus mode ",
            smallImageKey: " small ",
            smallImageText: " Small text ",
            usesElapsedTime: true,
            elapsedStartDate: startDate,
            usesParty: true,
            partyCurrent: 2,
            partyMax: 5
        )

        let payload = AppliedPresencePayload(customPresencePreset: preset)

        XCTAssertEqual(payload.name, "Focus")
        XCTAssertEqual(payload.activityType, .watching)
        XCTAssertEqual(payload.details, "Deep work")
        XCTAssertEqual(payload.state, "Writing")
        XCTAssertEqual(payload.largeImageKey, "focus")
        XCTAssertEqual(payload.largeImageText, "Focus mode")
        XCTAssertEqual(payload.smallImageKey, "small")
        XCTAssertEqual(payload.smallImageText, "Small text")
        XCTAssertEqual(payload.partyID, "preset:11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(payload.partyCurrent, 2)
        XCTAssertEqual(payload.partyMax, 5)
        XCTAssertEqual(payload.start, startDate)
        XCTAssertNil(payload.end)
    }

    func testAppliedPresencePayloadCodableRoundTrip() throws {
        let payload = AppliedPresencePayload(
            name: "Apple Music",
            state: "Artist",
            details: "Track",
            largeImageKey: "https://example.com/art.png",
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 1_200),
            activityType: .listening
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(AppliedPresencePayload.self, from: data)

        XCTAssertEqual(decoded, payload)
    }

    func testSettingsBackupCodableRoundTripPreservesUserSettings() throws {
        let presetID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        var settings = AppSettings()
        settings.bundleIDs = ["com.apple.dt.Xcode"]
        settings.preferredLanguage = .english
        settings.presencePriorityEnabled = false
        settings.resetElapsedTimeOnScheduledPresetRestore = true
        settings.customPresencePresets = [
            CustomPresencePreset(
                id: presetID,
                title: "Build",
                activityType: .playing,
                details: "Compiling",
                state: "Xcode"
            )
        ]
        settings.presenceScheduleRules = [
            PresenceScheduleRule(
                presetID: presetID,
                resetsElapsedTimeOnRestore: true
            )
        ]

        let data = try ConfigUtility.encodeSettingsBackup(
            settings: settings,
            exportedAt: Date(timeIntervalSince1970: 1_000),
            platform: "iOS",
            appVersion: "1.0",
            buildNumber: "1"
        )
        let backup = try ConfigUtility.decodeSettingsBackup(from: data)

        XCTAssertEqual(backup.schemaVersion, SettingsBackupFile.currentSchemaVersion)
        XCTAssertEqual(backup.platform, "iOS")
        XCTAssertEqual(backup.appVersion, "1.0")
        XCTAssertEqual(backup.buildNumber, "1")
        XCTAssertEqual(backup.settings.bundleIDs, ["com.apple.dt.Xcode"])
        XCTAssertEqual(backup.settings.preferredLanguage, .english)
        XCTAssertFalse(backup.settings.presencePriorityEnabled)
        XCTAssertTrue(backup.settings.resetElapsedTimeOnScheduledPresetRestore)
        XCTAssertEqual(backup.settings.customPresencePresets.first?.title, "Build")
        XCTAssertTrue(backup.settings.presenceScheduleRules.first?.resetsElapsedTimeOnRestore == true)
    }

    func testSettingsBackupMigratesLegacyScheduledRestoreElapsedTimeSettingToRules() throws {
        let json = """
        {
          "appName": "CraftPresence",
          "appVersion": "1.0",
          "buildNumber": "1",
          "exportedAt": "2026-05-06T00:00:00Z",
          "platform": "iOS",
          "schemaVersion": 1,
          "settings": {
            "customPresencePresets": [
              {
                "id": "22222222-2222-2222-2222-222222222222",
                "title": "Build",
                "activityType": "playing",
                "details": "Compiling",
                "state": "Xcode"
              }
            ],
            "presenceScheduleRules": [
              {
                "id": "33333333-3333-3333-3333-333333333333",
                "presetID": "22222222-2222-2222-2222-222222222222",
                "isEnabled": true,
                "mode": "timeRange",
                "weekdays": [2, 3, 4, 5, 6],
                "startTime": { "hour": 9, "minute": 0 },
                "endTime": { "hour": 18, "minute": 0 },
                "restorePolicy": "previousPresence",
                "priority": 0,
                "updatedAt": "2026-05-06T00:00:00Z"
              }
            ],
            "resetElapsedTimeOnScheduledPresetRestore": true
          }
        }
        """
        let backup = try ConfigUtility.decodeSettingsBackup(from: Data(json.utf8))

        XCTAssertTrue(backup.settings.presenceScheduleRules.first?.resetsElapsedTimeOnRestore == true)
    }

    func testSettingsBackupAcceptsDifferentAppVersionWithSupportedSchema() throws {
        var settings = AppSettings()
        settings.preferredLanguage = .japanese
        let backup = SettingsBackupFile(
            schemaVersion: SettingsBackupFile.currentSchemaVersion,
            appName: "CraftPresence",
            appVersion: "0.9",
            buildNumber: "42",
            exportedAt: Date(timeIntervalSince1970: 1_000),
            platform: "iOS",
            settings: settings
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        let decoded = try ConfigUtility.decodeSettingsBackup(from: data)

        XCTAssertEqual(decoded.appVersion, "0.9")
        XCTAssertEqual(decoded.buildNumber, "42")
        XCTAssertEqual(decoded.settings.preferredLanguage, .japanese)
    }

    func testSettingsBackupAcceptsLegacyRawAppSettingsJSON() throws {
        var settings = AppSettings()
        settings.bundleIDs = ["com.apple.Music"]
        settings.preferredLanguage = .korean
        settings.customPresenceDraft = CustomPresencePreset(
            title: "Legacy",
            activityType: .listening,
            details: "Track",
            state: "Artist",
            usesElapsedTime: true,
            elapsedStartDate: Date(timeIntervalSinceReferenceDate: 10)
        )

        let data = try JSONEncoder().encode(settings)
        let backup = try ConfigUtility.decodeSettingsBackup(from: data)

        XCTAssertEqual(backup.schemaVersion, SettingsBackupFile.currentSchemaVersion)
        XCTAssertEqual(backup.platform, "legacy")
        XCTAssertNil(backup.appVersion)
        XCTAssertEqual(backup.settings.bundleIDs, ["com.apple.Music"])
        XCTAssertEqual(backup.settings.preferredLanguage, .korean)
        XCTAssertEqual(backup.settings.customPresenceDraft?.title, "Legacy")
    }

    func testSettingsBackupClearsRuntimeOnlyState() throws {
        let presetID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let preset = CustomPresencePreset(
            id: presetID,
            title: "Runtime",
            activityType: .playing,
            details: "Active",
            state: "Publishing"
        )
        var settings = AppSettings()
        settings.customPresencePresets = [preset]
        settings.appliedCustomPresence = preset
        settings.appliedPresence = AppliedPresencePayload(name: "Runtime")
        settings.activeCustomPresencePresetID = presetID
        settings.activePresenceScheduleState = ActivePresenceScheduleState(
            ruleID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            presetID: presetID,
            activationKey: "runtime",
            mode: .timeRange,
            previousPresence: AppliedPresencePayload(name: "Previous"),
            previousPresetID: nil,
            startedAt: Date(timeIntervalSince1970: 1_000),
            expectedEnd: Date(timeIntervalSince1970: 2_000)
        )

        let data = try ConfigUtility.encodeSettingsBackup(settings: settings, platform: "iOS")
        let backup = try ConfigUtility.decodeSettingsBackup(from: data)

        XCTAssertNil(backup.settings.appliedCustomPresence)
        XCTAssertNil(backup.settings.appliedPresence)
        XCTAssertNil(backup.settings.activeCustomPresencePresetID)
        XCTAssertNil(backup.settings.activePresenceScheduleState)
        XCTAssertEqual(backup.settings.customPresencePresets, [preset])
    }

    func testSettingsBackupRejectsUnsupportedSchemaVersion() {
        let json = """
        {
          "appName": "CraftPresence",
          "exportedAt": "2026-05-06T00:00:00Z",
          "platform": "iOS",
          "schemaVersion": 999,
          "settings": {}
        }
        """
        let data = Data(json.utf8)

        XCTAssertThrowsError(try ConfigUtility.decodeSettingsBackup(from: data)) { error in
            XCTAssertEqual(error as? SettingsBackupError, .unsupportedSchemaVersion(999))
        }
    }

    func testSettingsBackupRejectsScheduleWithMissingPreset() throws {
        var settings = AppSettings()
        let missingPresetID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        settings.presenceScheduleRules = [
            PresenceScheduleRule(presetID: missingPresetID)
        ]

        let data = try ConfigUtility.encodeSettingsBackup(settings: settings, platform: "iOS")

        XCTAssertThrowsError(try ConfigUtility.decodeSettingsBackup(from: data)) { error in
            XCTAssertEqual(error as? SettingsBackupError, .scheduleReferencesMissingPreset(missingPresetID))
        }
    }
}
