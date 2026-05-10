package com.minepacu.craftpresence

import com.minepacu.craftpresence.core.config.AppLanguage
import com.minepacu.craftpresence.core.config.AppSettings
import com.minepacu.craftpresence.core.config.AppliedPresencePayload
import com.minepacu.craftpresence.core.config.ConfigUtility
import com.minepacu.craftpresence.core.config.PresencePreset
import com.minepacu.craftpresence.core.config.ProgramPresenceSettings
import com.minepacu.craftpresence.core.config.SettingsBackupFile
import com.minepacu.craftpresence.core.discord.DiscordActivity
import com.minepacu.craftpresence.core.discord.DiscordPresenceSource
import com.minepacu.craftpresence.core.discord.DiscordState
import com.minepacu.craftpresence.core.presence.ProgramPresenceSession
import com.minepacu.craftpresence.core.presence.resolveProgramPresenceSession
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class ExampleUnitTest {
    @Test
    fun discordStateExposesCurrentPresencePayloadAndSource() {
        val activity = DiscordActivity(
            name = "Example App",
            state = "Editing",
            details = "Using Example App",
            largeImageKey = "example_large",
            smallImageKey = "example_small",
            startEpochSeconds = 1_000L,
            activityType = DiscordActivity.ActivityType.PLAYING,
        )

        val state = DiscordState(
            currentActivity = activity,
            currentActivitySource = DiscordPresenceSource.APP,
        )

        assertEquals(activity, state.currentActivity)
        assertEquals(DiscordPresenceSource.APP, state.currentActivitySource)
    }

    @Test
    fun programPresenceSessionResetsWhenPackageChanges() {
        val previous = ProgramPresenceSession(
            packageName = "com.example.first",
            payloadKey = "payload",
            startEpochSeconds = 1_000L,
        )

        val next = resolveProgramPresenceSession(
            previous = previous,
            packageName = "com.example.second",
            payloadKey = "payload",
            resetElapsedTimeOnPresenceChange = false,
            nowEpochSeconds = 2_000L,
        )

        assertEquals(2_000L, next.startEpochSeconds)
    }

    @Test
    fun programPresenceSessionResetsWhenPayloadChangesAndToggleIsEnabled() {
        val previous = ProgramPresenceSession(
            packageName = "com.example.app",
            payloadKey = "old",
            startEpochSeconds = 1_000L,
        )

        val next = resolveProgramPresenceSession(
            previous = previous,
            packageName = "com.example.app",
            payloadKey = "new",
            resetElapsedTimeOnPresenceChange = true,
            nowEpochSeconds = 2_000L,
        )

        assertEquals(2_000L, next.startEpochSeconds)
    }

    @Test
    fun programPresenceSessionKeepsStartWhenPayloadChangesAndToggleIsDisabled() {
        val previous = ProgramPresenceSession(
            packageName = "com.example.app",
            payloadKey = "old",
            startEpochSeconds = 1_000L,
        )

        val next = resolveProgramPresenceSession(
            previous = previous,
            packageName = "com.example.app",
            payloadKey = "new",
            resetElapsedTimeOnPresenceChange = false,
            nowEpochSeconds = 2_000L,
        )

        assertEquals(1_000L, next.startEpochSeconds)
        assertEquals("new", next.payloadKey)
    }

    @Test
    fun programPresenceSessionKeepsStartWhenPayloadIsUnchanged() {
        val previous = ProgramPresenceSession(
            packageName = "com.example.app",
            payloadKey = "same",
            startEpochSeconds = 1_000L,
        )

        val next = resolveProgramPresenceSession(
            previous = previous,
            packageName = "com.example.app",
            payloadKey = "same",
            resetElapsedTimeOnPresenceChange = true,
            nowEpochSeconds = 2_000L,
        )

        assertEquals(1_000L, next.startEpochSeconds)
    }

    @Test
    fun programPresenceSettingsDefaultsResetElapsedTimeOnPresenceChangeToTrue() {
        val settings = ProgramPresenceSettings()

        assertTrue(settings.resetElapsedTimeOnPresenceChange)
    }

    @Test
    fun appSettingsDefaultsScheduledRestoreElapsedTimeResetToFalse() {
        val settings = AppSettings()

        assertEquals(false, settings.resetElapsedTimeOnScheduledPresetRestore)
    }

    @Test
    fun appSettingsDefaultsIncludeStableSharedPresencePresets() {
        val settings = AppSettings()

        assertEquals(5, settings.presencePresets.size)
        assertEquals("00000000-0000-0000-0000-000000000001", settings.presencePresets.first().id)
        assertTrue(settings.presencePresets.all { it.isDefault })
    }

    @Test
    fun presencePresetRoundTripPreservesSharedSchemaFields() {
        val preset = PresencePreset(
            id = "11111111-1111-1111-1111-111111111111",
            title = "Focus",
            activityType = DiscordActivity.ActivityType.WATCHING,
            details = "Deep work",
            state = "Writing",
            largeImageKey = "focus",
            largeImageText = "Focus mode",
            smallImageKey = "small",
            smallImageText = "Small text",
            usesElapsedTime = true,
            resetsElapsedTimeOnPublish = false,
            usesParty = true,
            partyCurrent = 2,
            partyMax = 5,
            isDefault = true,
            updatedAt = "2026-05-08T00:00:00.000Z",
        )

        val decoded = PresencePreset.fromJson(preset.toJson())

        assertEquals(preset, decoded)
    }

    @Test
    fun presencePresetBuildsDiscordActivityPayload() {
        val preset = PresencePreset(
            id = "11111111-1111-1111-1111-111111111111",
            title = "Focus",
            details = "Deep work",
            state = "Writing",
            usesParty = true,
            partyCurrent = 2,
            partyMax = 5,
        )

        val activity = preset.toDiscordActivity(nowEpochSeconds = 1_000L)

        assertEquals("Focus", activity.name)
        assertEquals("Deep work", activity.details)
        assertEquals("Writing", activity.state)
        assertEquals("preset:11111111-1111-1111-1111-111111111111", activity.partyId)
        assertEquals(2, activity.partyCurrent)
        assertEquals(5, activity.partyMax)
        assertEquals(1_000L, activity.startEpochSeconds)
    }

    @Test
    fun presencePresetOmitsDisabledElapsedTimeAndPartyPayload() {
        val preset = PresencePreset(
            id = "11111111-1111-1111-1111-111111111111",
            title = "Focus",
            details = "Deep work",
            state = "Writing",
            usesElapsedTime = false,
            usesParty = false,
            partyCurrent = 2,
            partyMax = 5,
        )

        val activity = preset.toDiscordActivity(nowEpochSeconds = 1_000L)

        assertEquals(null, activity.partyId)
        assertEquals(null, activity.partyCurrent)
        assertEquals(null, activity.partyMax)
        assertEquals(null, activity.startEpochSeconds)
    }

    @Test
    fun presencePresetReusesPreviousStartWhenSamePayloadIsRepublishedWithoutReset() {
        val preset = PresencePreset(
            id = "11111111-1111-1111-1111-111111111111",
            title = "Focus",
            details = "Deep work",
            state = "Writing",
            resetsElapsedTimeOnPublish = false,
        )
        val previous = AppliedPresencePayload.fromPreset(preset, nowEpochSeconds = 1_000L)

        val activity = preset.toDiscordActivity(
            nowEpochSeconds = 2_000L,
            previousPayload = previous,
        )

        assertEquals(1_000L, activity.startEpochSeconds)
    }

    @Test
    fun presencePresetStartsNewElapsedTimeWhenPayloadChanges() {
        val previousPreset = PresencePreset(
            id = "11111111-1111-1111-1111-111111111111",
            title = "Focus",
            details = "Deep work",
            state = "Writing",
            resetsElapsedTimeOnPublish = false,
        )
        val nextPreset = previousPreset.copy(state = "Reviewing")
        val previous = AppliedPresencePayload.fromPreset(previousPreset, nowEpochSeconds = 1_000L)

        val activity = nextPreset.toDiscordActivity(
            nowEpochSeconds = 2_000L,
            previousPayload = previous,
        )

        assertEquals(2_000L, activity.startEpochSeconds)
    }

    @Test
    fun presencePresetStartsNewElapsedTimeWhenResetOnPublishIsEnabled() {
        val preset = PresencePreset(
            id = "11111111-1111-1111-1111-111111111111",
            title = "Focus",
            details = "Deep work",
            state = "Writing",
            resetsElapsedTimeOnPublish = true,
        )
        val previous = AppliedPresencePayload.fromPreset(preset, nowEpochSeconds = 1_000L)

        val activity = preset.toDiscordActivity(
            nowEpochSeconds = 2_000L,
            previousPayload = previous,
        )

        assertEquals(2_000L, activity.startEpochSeconds)
    }

    @Test
    fun appliedPresenceFromPresetUsesResolvedElapsedTime() {
        val preset = PresencePreset(
            id = "11111111-1111-1111-1111-111111111111",
            title = "Focus",
            details = "Deep work",
            state = "Writing",
            resetsElapsedTimeOnPublish = false,
        )
        val previous = AppliedPresencePayload.fromPreset(preset, nowEpochSeconds = 1_000L)

        val payload = AppliedPresencePayload.fromPreset(
            preset = preset,
            nowEpochSeconds = 2_000L,
            previousPayload = previous,
        )

        assertEquals(1_000L, payload.startEpochSeconds)
    }

    @Test
    fun appliedPresenceRoundTripPreservesSharedPayloadFields() {
        val payload = AppliedPresencePayload(
            name = "Focus",
            state = "Writing",
            details = "Deep work",
            partyID = "preset:11111111-1111-1111-1111-111111111111",
            partyCurrent = 2,
            partyMax = 5,
            startEpochSeconds = 1_000L,
            activityType = DiscordActivity.ActivityType.PLAYING,
        )

        val decoded = AppliedPresencePayload.fromJson(payload.toJson())

        assertEquals(payload, decoded)
    }

    @Test
    fun settingsBackupIncludesSharedExtensionEnvelopeAndSummary() {
        val backup = SettingsBackupFile(
            schemaVersion = SettingsBackupFile.CURRENT_SCHEMA_VERSION,
            appName = "CraftPresence",
            appVersion = "1.0",
            buildNumber = "1",
            exportedAt = "2026-05-08T00:00:00.000Z",
            platform = "Android",
            settings = AppSettings(packageNames = listOf("com.example.app")),
            platformExtensions = JSONObject().put("android", JSONObject().put("notification", true)),
        )

        val decoded = SettingsBackupFile.decode(backup.toJson().toString())
        val summary = decoded.importSummary()

        assertTrue(decoded.toJson().has("platformExtensions"))
        assertEquals(listOf("android"), summary.ignoredPlatformExtensionKeys)
        assertEquals(5, summary.presetCount)
        assertEquals(1, summary.trackedProgramCount)
    }

    @Test
    fun defaultBackupFilenameUsesCraftPresenceExtension() {
        assertTrue(ConfigUtility.defaultSettingsBackupFilename().endsWith(".craftpresence.json"))
    }

    @Test
    fun settingsBackupRoundTripPreservesUserSettingsAcrossAppVersions() {
        val settings = AppSettings(
            packageNames = listOf("com.example.app"),
            appDisplayNames = mapOf("com.example.app" to "Example"),
            programSettings = mapOf(
                "com.example.app" to ProgramPresenceSettings(
                    presetID = "00000000-0000-0000-0000-000000000001",
                    detailText = "Using {app}",
                ),
            ),
            activePresencePresetID = "00000000-0000-0000-0000-000000000001",
            preferredLanguage = AppLanguage.ENGLISH,
            programPresenceEnabled = false,
            resetElapsedTimeOnScheduledPresetRestore = true,
        )
        val backup = SettingsBackupFile(
            schemaVersion = SettingsBackupFile.CURRENT_SCHEMA_VERSION,
            appName = "CraftPresence",
            appVersion = "9.9.9",
            buildNumber = "999",
            exportedAt = "2026-05-06T00:00:00.000Z",
            platform = "Android",
            settings = settings,
        )

        val decoded = SettingsBackupFile.decode(backup.toJson().toString())

        assertEquals("9.9.9", decoded.appVersion)
        assertEquals("999", decoded.buildNumber)
        assertEquals(settings, decoded.settingsForImport())
        assertTrue(decoded.settingsForImport().resetElapsedTimeOnScheduledPresetRestore)
    }

    @Test
    fun settingsBackupAcceptsLegacyRawAppSettingsJson() {
        val settings = AppSettings(
            packageNames = listOf("com.example.legacy"),
            preferredLanguage = AppLanguage.KOREAN,
        )

        val decoded = SettingsBackupFile.decode(settings.toJson().toString())

        assertEquals("legacy", decoded.platform)
        assertEquals(SettingsBackupFile.CURRENT_SCHEMA_VERSION, decoded.schemaVersion)
        assertEquals(settings, decoded.settingsForImport())
    }

    @Test
    fun settingsBackupRejectsUnsupportedSchemaVersion() {
        val backup = SettingsBackupFile(
            schemaVersion = SettingsBackupFile.CURRENT_SCHEMA_VERSION + 1,
            appName = "CraftPresence",
            appVersion = "1.0",
            buildNumber = "1",
            exportedAt = "2026-05-06T00:00:00.000Z",
            platform = "Android",
            settings = AppSettings(),
        )

        assertThrows(IllegalArgumentException::class.java) {
            SettingsBackupFile.decode(backup.toJson().toString())
        }
    }

    @Test
    fun settingsBackupAcceptsSupportedApplePlatforms() {
        val backup = SettingsBackupFile(
            schemaVersion = SettingsBackupFile.CURRENT_SCHEMA_VERSION,
            appName = "CraftPresence",
            appVersion = "1.0",
            buildNumber = "1",
            exportedAt = "2026-05-06T00:00:00.000Z",
            platform = "iOS",
            settings = AppSettings(),
        )

        assertEquals("iOS", SettingsBackupFile.decode(backup.toJson().toString()).platform)
    }

    @Test
    fun settingsBackupRejectsMissingActivePresencePresetReference() {
        val backup = SettingsBackupFile(
            schemaVersion = SettingsBackupFile.CURRENT_SCHEMA_VERSION,
            appName = "CraftPresence",
            appVersion = "1.0",
            buildNumber = "1",
            exportedAt = "2026-05-06T00:00:00.000Z",
            platform = "Android",
            settings = AppSettings(activePresencePresetID = "missing"),
        )

        assertThrows(IllegalArgumentException::class.java) {
            SettingsBackupFile.decode(backup.toJson().toString())
        }
    }
}
