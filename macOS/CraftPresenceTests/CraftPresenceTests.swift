			//
//  CraftPresenceTests.swift
//  CraftPresenceTests
//
//  Created by 노현수 on 10/31/25.
//

import Foundation
import Testing
@testable import CraftPresence

struct CraftPresenceTests {

    @Test func example() async throws {
        let settings = AppSettings()

        #expect(settings.presencePresets.count == 5)
        #expect(settings.presencePresets.first?.id.uuidString == "00000000-0000-0000-0000-000000000001")
        #expect(settings.presencePresets.allSatisfy { $0.isDefault })
    }

    @Test func sharedPresencePresetCodingKeyDecodes() async throws {
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

        #expect(settings.presencePresets.first?.title == "Focus")
        #expect(settings.presencePresets.first?.activityType == .watching)
        #expect(settings.presencePresets.first?.isDefault == true)
        #expect(settings.activePresencePresetID?.uuidString == "11111111-1111-1111-1111-111111111111")
    }

    @Test func appliedPresencePayloadPreservesPresetFields() async throws {
        let startDate = Date(timeIntervalSince1970: 1_000)
        let preset = PresencePreset(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: " Focus ",
            activityType: .watching,
            details: " Deep work ",
            state: " Writing ",
            usesElapsedTime: true,
            elapsedStartDate: startDate,
            pausedElapsedDuration: 3_900,
            resetsElapsedTimeOnPublish: false,
            usesParty: true,
            partyCurrent: 2,
            partyMax: 5
        )

        let payload = AppliedPresencePayload(presencePreset: preset)

        #expect(payload.name == "Focus")
        #expect(payload.source == .manual)
        #expect(payload.activityType == .watching)
        #expect(payload.details == "Deep work")
        #expect(payload.state == "Writing")
        #expect(payload.partyID == "preset:11111111-1111-1111-1111-111111111111")
        #expect(payload.partyCurrent == 2)
        #expect(payload.partyMax == 5)
        #expect(payload.start == startDate)
    }

    @Test func presencePresetRoundTripPreservesElapsedStartDate() async throws {
        let startDate = Date(timeIntervalSince1970: 1_000)
        let preset = PresencePreset(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Focus",
            activityType: .watching,
            details: "Deep work",
            state: "Writing",
            usesElapsedTime: true,
            elapsedStartDate: startDate,
            pausedElapsedDuration: 3_900,
            resetsElapsedTimeOnPublish: false
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(PresencePreset.self, from: encoder.encode(preset))

        #expect(decoded.elapsedStartDate == startDate)
        #expect(decoded.pausedElapsedDurationForDisplay == 3_900)
    }

    @Test func presencePresetCapturesPausedElapsedDurationAtPublishTime() async throws {
        let preset = PresencePreset(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Focus",
            activityType: .watching,
            details: "Deep work",
            state: "Writing",
            usesElapsedTime: true,
            elapsedStartDate: Date(timeIntervalSince1970: 1_000),
            resetsElapsedTimeOnPublish: false
        )

        #expect(preset.pausedElapsedDurationForPublish(now: Date(timeIntervalSince1970: 4_900)) == 3_900)
    }

    @Test func appliedPresencePayloadDecodesLegacySourceAsManual() async throws {
        let json = """
        {
          "name": "Focus",
          "state": "Writing",
          "details": "Deep work",
          "activityType": "Watching"
        }
        """

        let payload = try JSONDecoder().decode(AppliedPresencePayload.self, from: Data(json.utf8))

        #expect(payload.source == .manual)
    }

    @Test func settingsDecodeMissingPresencePriorityAsEnabled() async throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))

        #expect(settings.presencePriorityEnabled == true)
    }

    @Test func settingsOnlyClearsAppliedPresenceForMatchingSource() async throws {
        var settings = AppSettings()
        settings.appliedPresence = AppliedPresencePayload(
            name: "Focus",
            state: "Writing",
            details: "Deep work",
            source: .manual
        )

        #expect(settings.clearAppliedPresence(ifOwnedBy: .appleMusic) == false)
        #expect(settings.appliedPresence?.name == "Focus")

        #expect(settings.clearAppliedPresence(ifOwnedBy: .manual) == true)
        #expect(settings.appliedPresence == nil)
    }

    @Test func settingsBackupRoundTripIncludesPlatformExtensionsAndSummary() async throws {
        var settings = AppSettings()
        settings.bundleIDs = ["com.apple.dt.Xcode"]
        settings.preferredLanguage = .english
        settings.presencePriorityEnabled = false

        let data = try ConfigUtility.encodeSettingsBackup(
            settings: settings,
            exportedAt: Date(timeIntervalSince1970: 1_000),
            platform: "macOS",
            platformExtensions: ["macOS": "menuBarOnly=true"]
        )
        let backup = try ConfigUtility.decodeSettingsBackup(from: data)
        let summary = backup.importSummary()

        #expect(backup.platformExtensions == ["macOS": "menuBarOnly=true"])
        #expect(summary.platform == "macOS")
        #expect(summary.presetCount == 5)
        #expect(summary.trackedProgramCount == 1)
        #expect(backup.settings.presencePriorityEnabled == false)
        #expect(summary.ignoredPlatformExtensionKeys == ["macOS"])
    }

    @Test func settingsBackupRejectsMissingActivePresetReference() async throws {
        var settings = AppSettings()
        settings.activePresencePresetID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")
        let backup = SettingsBackupFile(settings: settings)

        do {
            try ConfigUtility.validateSettingsBackup(backup)
            Issue.record("Expected missing active preset validation to fail.")
        } catch let error as SettingsBackupError {
            #expect(error == .missingActivePreset(UUID(uuidString: "99999999-9999-9999-9999-999999999999")!))
        }
    }

    @Test func defaultBackupFilenameUsesCraftPresenceExtension() async throws {
        let filename = ConfigUtility.defaultSettingsBackupFilename(now: Date(timeIntervalSince1970: 1_000))

        #expect(filename.hasSuffix(".craftpresence.json"))
    }

    @Test func settingsDuplicatePresencePresetCreatesEditableCopy() async throws {
        var settings = AppSettings()
        let sourceID = PresencePreset.defaults[0].id

        let copy = settings.duplicatePresencePreset(id: sourceID, title: "Coding Copy")

        #expect(copy != nil)
        #expect(copy?.id != sourceID)
        #expect(copy?.title == "Coding Copy")
        #expect(copy?.isDefault == false)
        #expect(settings.presencePresets.contains { $0.id == copy?.id })
    }

    @Test func settingsRemovePresencePresetClearsActiveAndAppliedPresetState() async throws {
        var settings = AppSettings()
        let sourceID = PresencePreset.defaults[0].id
        settings.activePresencePresetID = sourceID
        settings.appliedPresence = AppliedPresencePayload(presencePreset: PresencePreset.defaults[0])

        settings.removePresencePreset(id: sourceID)

        #expect(settings.presencePresets.contains { $0.id == sourceID } == false)
        #expect(settings.activePresencePresetID == nil)
        #expect(settings.appliedPresence == nil)
    }

    @Test func settingsRestoreDefaultPresencePresetsOnlyAddsMissingDefaults() async throws {
        var settings = AppSettings()
        let removedDefaultID = PresencePreset.defaults[0].id
        let customPreset = PresencePreset(
            title: "Custom",
            activityType: .playing,
            details: "Custom details",
            state: "Custom state"
        )
        settings.presencePresets = Array(PresencePreset.defaults.dropFirst()) + [customPreset]

        settings.restoreDefaultPresencePresets()

        #expect(settings.presencePresets.contains { $0.id == removedDefaultID })
        #expect(settings.presencePresets.contains { $0.id == customPreset.id })
        #expect(settings.presencePresets.count == PresencePreset.defaults.count + 1)
    }

}
