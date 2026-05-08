package com.minepacu.craftpresence

import com.minepacu.craftpresence.core.config.AppLanguage
import com.minepacu.craftpresence.core.config.AppSettings
import com.minepacu.craftpresence.core.config.ProgramPresenceSettings
import com.minepacu.craftpresence.core.config.SettingsBackupFile
import com.minepacu.craftpresence.core.discord.DiscordActivity
import com.minepacu.craftpresence.core.discord.DiscordPresenceSource
import com.minepacu.craftpresence.core.discord.DiscordState
import com.minepacu.craftpresence.core.presence.ProgramPresenceSession
import com.minepacu.craftpresence.core.presence.resolveProgramPresenceSession
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
    fun settingsBackupRoundTripPreservesUserSettingsAcrossAppVersions() {
        val settings = AppSettings(
            packageNames = listOf("com.example.app"),
            appDisplayNames = mapOf("com.example.app" to "Example"),
            programSettings = mapOf(
                "com.example.app" to ProgramPresenceSettings(detailText = "Using {app}"),
            ),
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
    fun settingsBackupRejectsUnsupportedPlatform() {
        val backup = SettingsBackupFile(
            schemaVersion = SettingsBackupFile.CURRENT_SCHEMA_VERSION,
            appName = "CraftPresence",
            appVersion = "1.0",
            buildNumber = "1",
            exportedAt = "2026-05-06T00:00:00.000Z",
            platform = "iOS",
            settings = AppSettings(),
        )

        assertThrows(IllegalArgumentException::class.java) {
            SettingsBackupFile.decode(backup.toJson().toString())
        }
    }
}
