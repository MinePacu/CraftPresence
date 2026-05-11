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
        XCTAssertNil(payload.streamingURL)
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

    func testStreamingPresenceRequiresYoutubeOrTwitchURL() {
        let youtubePreset = CustomPresencePreset(
            title: "Live",
            activityType: .streaming,
            details: "Building",
            state: "On air",
            streamingURL: " https://www.youtube.com/watch?v=abc123 "
        )
        let twitchPreset = CustomPresencePreset(
            title: "Live",
            activityType: .streaming,
            details: "Building",
            state: "On air",
            streamingURL: "https://twitch.tv/example"
        )
        let missingURLPreset = CustomPresencePreset(
            title: "Live",
            activityType: .streaming,
            details: "Building",
            state: "On air",
            streamingURL: ""
        )
        let unsupportedURLPreset = CustomPresencePreset(
            title: "Live",
            activityType: .streaming,
            details: "Building",
            state: "On air",
            streamingURL: "https://example.com/live"
        )

        XCTAssertNil(youtubePreset.streamingURLValidationError)
        XCTAssertEqual(youtubePreset.normalized.streamingURL, "https://www.youtube.com/watch?v=abc123")
        XCTAssertNil(twitchPreset.streamingURLValidationError)
        XCTAssertEqual(missingURLPreset.streamingURLValidationError, .missing)
        XCTAssertEqual(unsupportedURLPreset.streamingURLValidationError, .unsupportedHost)
    }

    func testNonStreamingPresenceIgnoresStreamingURLValidation() {
        let preset = CustomPresencePreset(
            title: "Focus",
            activityType: .playing,
            details: "Building",
            state: "Working",
            streamingURL: "https://example.com/live"
        )

        XCTAssertNil(preset.streamingURLValidationError)
        XCTAssertEqual(preset.normalized.streamingURL, "")
    }

    func testDefaultPresencePresetsUseStableSharedIDs() {
        let defaults = CustomPresencePreset.defaults

        XCTAssertEqual(defaults.count, 5)
        XCTAssertEqual(defaults.first?.id.uuidString, "00000000-0000-0000-0000-000000000001")
        XCTAssertTrue(defaults.allSatisfy { $0.isDefault })
    }

    func testPresencePresetsSharedCodingKeyDecodesIntoExistingIOSModel() throws {
        let json = """
        {
          "presencePresets": [
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "title": "Focus",
              "activityType": "Watching",
              "details": "Deep work",
              "state": "Writing",
              "isDefault": true,
              "updatedAt": "2026-05-08T00:00:00Z"
            }
          ],
          "activePresencePresetID": "11111111-1111-1111-1111-111111111111"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let settings = try decoder.decode(AppSettings.self, from: Data(json.utf8))

        XCTAssertEqual(settings.customPresencePresets.first?.title, "Focus")
        XCTAssertEqual(settings.customPresencePresets.first?.activityType, .watching)
        XCTAssertTrue(settings.customPresencePresets.first?.isDefault == true)
        XCTAssertEqual(settings.activeCustomPresencePresetID?.uuidString, "11111111-1111-1111-1111-111111111111")
    }

    func testDynamicIslandContentOptionsDefaultToCurrentLiveActivityOutput() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))

        XCTAssertTrue(settings.liveActivityContentOptions.presenceSummary)
        XCTAssertTrue(settings.liveActivityContentOptions.elapsedTime)
        XCTAssertTrue(settings.liveActivityContentOptions.discordStatus)
    }

    func testDynamicIslandContentOptionsCodableRoundTrip() throws {
        var settings = AppSettings()
        settings.liveActivityContentOptions = LiveActivityContentOptions(
            presenceSummary: true,
            elapsedTime: false,
            discordStatus: true
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.liveActivityContentOptions, settings.liveActivityContentOptions)
    }

    #if canImport(ActivityKit)
    func testPresenceActivityContentStateDefaultsMissingContentOptions() throws {
        let json = """
        {
          "title": "Focus",
          "details": "Deep work",
          "state": "Writing",
          "connectionStatus": "Ready",
          "isLive": true
        }
        """

        let decoded = try JSONDecoder().decode(
            PresenceActivityAttributes.ContentState.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(decoded.contentOptions, LiveActivityContentOptions())
    }
    #endif

    func testAppliedPresencePayloadCodableRoundTrip() throws {
        let payload = AppliedPresencePayload(
            name: "Apple Music",
            state: "Artist",
            details: "Track",
            largeImageKey: "https://example.com/art.png",
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 1_200),
            activityType: .listening,
            source: .appleMusic
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(AppliedPresencePayload.self, from: data)

        XCTAssertEqual(decoded, payload)
    }

    func testAppliedPresencePayloadDefaultsLegacyDecodeToManualSource() throws {
        let json = """
        {
          "name": "Focus",
          "state": "Writing",
          "details": "Deep work",
          "activityType": "playing"
        }
        """

        let decoded = try JSONDecoder().decode(AppliedPresencePayload.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.source, .manual)
    }

    func testGuardedAppliedPresenceClearDoesNotRemoveManualPayloadForOtherSource() async throws {
        let originalSettings = await ConfigUtility.shared.currentSettings()
        do {
            let payload = AppliedPresencePayload(
                name: "Focus",
                details: "Deep work",
                activityType: .playing,
                source: .manual
            )
            var settings = AppSettings()
            settings.appliedPresence = payload
            _ = try await ConfigUtility.shared.setSettings(settings)

            _ = try await ConfigUtility.shared.clearAppliedPresence(ifOwnedBy: .appleMusic)

            let current = await ConfigUtility.shared.currentAppliedPresence()
            XCTAssertEqual(current, payload)
            _ = try await ConfigUtility.shared.setSettings(originalSettings)
        } catch {
            _ = try? await ConfigUtility.shared.setSettings(originalSettings)
            throw error
        }
    }

    func testGuardedAppliedPresenceClearRemovesPayloadForMatchingSource() async throws {
        let originalSettings = await ConfigUtility.shared.currentSettings()
        do {
            let payload = AppliedPresencePayload(
                name: "Apple Music",
                details: "Track",
                activityType: .listening,
                source: .appleMusic
            )
            var settings = AppSettings()
            settings.appliedPresence = payload
            _ = try await ConfigUtility.shared.setSettings(settings)

            _ = try await ConfigUtility.shared.clearAppliedPresence(ifOwnedBy: .appleMusic)

            let current = await ConfigUtility.shared.currentAppliedPresence()
            XCTAssertNil(current)
            _ = try await ConfigUtility.shared.setSettings(originalSettings)
        } catch {
            _ = try? await ConfigUtility.shared.setSettings(originalSettings)
            throw error
        }
    }

    func testSingleTimeScheduleMatchesLateWakeWithinGraceWindow() {
        let presetID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let ruleID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let preset = CustomPresencePreset(
            id: presetID,
            title: "Focus",
            activityType: .playing,
            details: "Deep work",
            state: "Writing"
        )
        var settings = AppSettings()
        settings.customPresencePresets = [preset]
        settings.presenceScheduleRules = [
            PresenceScheduleRule(
                id: ruleID,
                presetID: presetID,
                mode: .singleTime,
                weekdays: [.monday],
                startTime: PresenceScheduleTime(hour: 9, minute: 0)
            )
        ]
        let now = testDate(year: 2026, month: 5, day: 4, hour: 9, minute: 4)

        let match = PresenceScheduleEvaluator.activeMatch(in: settings, now: now, calendar: testCalendar)

        XCTAssertEqual(match?.rule.id, ruleID)
    }

    func testSingleTimeScheduleDoesNotMatchAfterActivationWasRecorded() {
        let presetID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let ruleID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let preset = CustomPresencePreset(
            id: presetID,
            title: "Focus",
            activityType: .playing,
            details: "Deep work",
            state: "Writing"
        )
        let rule = PresenceScheduleRule(
            id: ruleID,
            presetID: presetID,
            mode: .singleTime,
            weekdays: [.monday],
            startTime: PresenceScheduleTime(hour: 9, minute: 0)
        )
        var settings = AppSettings()
        settings.customPresencePresets = [preset]
        settings.presenceScheduleRules = [rule]
        let now = testDate(year: 2026, month: 5, day: 4, hour: 9, minute: 4)
        let activationKey = PresenceScheduleEvaluator.activationKey(
            for: rule,
            occurrenceStart: testDate(year: 2026, month: 5, day: 4, hour: 9, minute: 0),
            calendar: testCalendar
        )
        settings.completedPresenceScheduleActivationKeys = [ruleID.uuidString: activationKey]

        let match = PresenceScheduleEvaluator.activeMatch(in: settings, now: now, calendar: testCalendar)

        XCTAssertNil(match)
    }

    func testBackgroundSchedulePlannerReturnsNextEnabledScheduleDate() {
        let presetID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        var settings = AppSettings()
        settings.customPresencePresets = [
            CustomPresencePreset(
                id: presetID,
                title: "Focus",
                activityType: .playing,
                details: "Deep work",
                state: "Writing"
            )
        ]
        settings.presenceScheduleRules = [
            PresenceScheduleRule(
                presetID: presetID,
                mode: .timeRange,
                weekdays: [.monday],
                startTime: PresenceScheduleTime(hour: 9, minute: 0),
                endTime: PresenceScheduleTime(hour: 18, minute: 0)
            )
        ]
        let now = testDate(year: 2026, month: 5, day: 4, hour: 8, minute: 30)

        let wakeDate = PresenceScheduleBackgroundPlan.nextWakeDate(in: settings, now: now, calendar: testCalendar)

        XCTAssertEqual(wakeDate, testDate(year: 2026, month: 5, day: 4, hour: 9, minute: 0))
    }

    #if canImport(ActivityKit)
    func testLiveActivityContentStateCanBeBuiltFromAppliedPresencePayload() {
        let startDate = Date(timeIntervalSince1970: 1_000)
        let payload = AppliedPresencePayload(
            name: " Focus ",
            state: " Writing ",
            details: " Deep work ",
            start: startDate,
            activityType: .playing
        )
        let options = LiveActivityContentOptions(presenceSummary: true, elapsedTime: false, discordStatus: true)

        let state = PresenceLiveActivityContentBuilder.contentState(
            for: payload,
            connectionStatus: "Connected",
            isLive: true,
            contentOptions: options
        )

        XCTAssertEqual(state.title, "Focus")
        XCTAssertEqual(state.details, "Deep work")
        XCTAssertEqual(state.state, "Writing")
        XCTAssertEqual(state.connectionStatus, "Connected")
        XCTAssertNil(state.startedAt)
        XCTAssertEqual(state.contentOptions, options)
    }
    #endif

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
        XCTAssertEqual(backup.settings.customPresencePresets.first?.isDefault, false)
        XCTAssertTrue(backup.settings.presenceScheduleRules.first?.resetsElapsedTimeOnRestore == true)
    }

    func testSettingsBackupIncludesPlatformExtensionsAndImportSummary() throws {
        var settings = AppSettings()
        settings.bundleIDs = ["com.apple.dt.Xcode"]
        settings.preferredLanguage = .english

        let data = try ConfigUtility.encodeSettingsBackup(
            settings: settings,
            exportedAt: Date(timeIntervalSince1970: 1_000),
            platform: "iOS",
            platformExtensions: ["ios": "liveActivity=true"]
        )
        let backup = try ConfigUtility.decodeSettingsBackup(from: data)
        let summary = backup.importSummary()

        XCTAssertEqual(backup.platformExtensions, ["ios": "liveActivity=true"])
        XCTAssertEqual(summary.platform, "iOS")
        XCTAssertEqual(summary.presetCount, 5)
        XCTAssertEqual(summary.trackedProgramCount, 1)
        XCTAssertEqual(summary.ignoredPlatformExtensionKeys, ["ios"])
    }

    func testDefaultSettingsBackupFilenameUsesCraftPresenceExtension() {
        let filename = ConfigUtility.defaultSettingsBackupFilename(now: Date(timeIntervalSince1970: 1_000))

        XCTAssertTrue(filename.hasSuffix(".craftpresence.json"))
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

    func testCustomPresencePresetReorderValidationRequiresSamePresetIDs() throws {
        let first = CustomPresencePreset(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            title: "First",
            activityType: .playing,
            details: "First details",
            state: "First state"
        )
        let second = CustomPresencePreset(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            title: "Second",
            activityType: .playing,
            details: "Second details",
            state: "Second state"
        )
        let replacement = CustomPresencePreset(
            id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
            title: "Replacement",
            activityType: .playing,
            details: "Replacement details",
            state: "Replacement state"
        )

        XCTAssertNoThrow(
            try ConfigUtility.validateCustomPresencePresetReorder(
                existing: [first, second],
                reordered: [second, first]
            )
        )
        XCTAssertThrowsError(
            try ConfigUtility.validateCustomPresencePresetReorder(
                existing: [first, second],
                reordered: [second, replacement]
            )
        ) { error in
            XCTAssertEqual(error as? ConfigUtilityError, .invalidPresetReorder)
        }
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func testDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        testCalendar.date(
            from: DateComponents(
                timeZone: TimeZone(secondsFromGMT: 0)!,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
