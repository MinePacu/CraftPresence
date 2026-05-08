			//
//  CraftPresenceTests.swift
//  CraftPresenceTests
//
//  Created by 노현수 on 10/31/25.
//

import Testing

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
        let preset = PresencePreset(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: " Focus ",
            activityType: .watching,
            details: " Deep work ",
            state: " Writing ",
            usesParty: true,
            partyCurrent: 2,
            partyMax: 5
        )

        let payload = AppliedPresencePayload(presencePreset: preset)

        #expect(payload.name == "Focus")
        #expect(payload.activityType == .watching)
        #expect(payload.details == "Deep work")
        #expect(payload.state == "Writing")
        #expect(payload.partyID == "preset:11111111-1111-1111-1111-111111111111")
        #expect(payload.partyCurrent == 2)
        #expect(payload.partyMax == 5)
    }

    @Test func settingsBackupRoundTripIncludesPlatformExtensionsAndSummary() async throws {
        var settings = AppSettings()
        settings.bundleIDs = ["com.apple.dt.Xcode"]
        settings.preferredLanguage = .english

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

}
