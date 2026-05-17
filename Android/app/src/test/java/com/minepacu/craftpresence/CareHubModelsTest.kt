package com.minepacu.craftpresence

import com.minepacu.craftpresence.ui.care.CareHubActionTarget
import com.minepacu.craftpresence.ui.care.CareHubHealthLevel
import com.minepacu.craftpresence.ui.care.resolveCareHubHealth
import com.minepacu.craftpresence.ui.care.resolvePermissionSummary
import com.minepacu.craftpresence.ui.care.resolveTrackedAppsState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CareHubModelsTest {
    @Test
    fun careHubHealthPrioritizesDiscordSetup() {
        val health = resolveCareHubHealth(
            discordReady = false,
            registeredAppCount = 0,
            foregroundDetectionEnabled = false,
            missingPermissionCount = 3,
        )

        assertEquals(CareHubHealthLevel.NEEDS_ATTENTION, health.level)
        assertEquals(CareHubActionTarget.DISCORD, health.actionTarget)
    }

    @Test
    fun careHubHealthPrioritizesPermissionsBeforePresenceEditing() {
        val health = resolveCareHubHealth(
            discordReady = true,
            registeredAppCount = 2,
            foregroundDetectionEnabled = true,
            missingPermissionCount = 1,
        )

        assertEquals(CareHubHealthLevel.NEEDS_ATTENTION, health.level)
        assertEquals(CareHubActionTarget.PERMISSIONS, health.actionTarget)
    }

    @Test
    fun careHubHealthIsReadyWhenSetupIsComplete() {
        val health = resolveCareHubHealth(
            discordReady = true,
            registeredAppCount = 2,
            foregroundDetectionEnabled = true,
            missingPermissionCount = 0,
        )

        assertEquals(CareHubHealthLevel.GOOD, health.level)
        assertEquals(CareHubActionTarget.PRESENCE, health.actionTarget)
    }

    @Test
    fun permissionSummaryCountsMissingPermissions() {
        val summary = resolvePermissionSummary(
            usageGranted = true,
            appNotificationGranted = false,
            notificationListenerGranted = false,
        )

        assertEquals(2, summary.missingCount)
        assertFalse(summary.complete)
    }

    @Test
    fun trackedAppsStateLocksEditingWhenForegroundDetectionIsOff() {
        val state = resolveTrackedAppsState(
            foregroundDetectionEnabled = false,
            registeredAppCount = 3,
            currentPackageName = "com.discord",
            currentPackageRegistered = false,
        )

        assertFalse(state.canAddCurrentApp)
        assertFalse(state.canEditRegisteredApps)
        assertTrue(state.locked)
    }

    @Test
    fun trackedAppsStateEnablesEditingWhenForegroundDetectionIsOn() {
        val state = resolveTrackedAppsState(
            foregroundDetectionEnabled = true,
            registeredAppCount = 3,
            currentPackageName = "com.discord",
            currentPackageRegistered = false,
        )

        assertTrue(state.canAddCurrentApp)
        assertTrue(state.canEditRegisteredApps)
        assertFalse(state.locked)
    }
}
