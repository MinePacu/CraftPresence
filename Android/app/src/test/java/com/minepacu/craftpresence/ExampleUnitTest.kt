package com.minepacu.craftpresence

import com.minepacu.craftpresence.core.config.ProgramPresenceSettings
import com.minepacu.craftpresence.core.presence.ProgramPresenceSession
import com.minepacu.craftpresence.core.presence.resolveProgramPresenceSession
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ExampleUnitTest {
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
}
