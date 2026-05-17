package com.minepacu.craftpresence.ui.care

enum class CareHubHealthLevel {
    GOOD,
    NEEDS_ATTENTION,
}

enum class CareHubActionTarget {
    DISCORD,
    TRACKED_APPS,
    PERMISSIONS,
    PRESENCE,
}

data class CareHubHealth(
    val level: CareHubHealthLevel,
    val actionTarget: CareHubActionTarget,
)

data class PermissionSummary(
    val missingCount: Int,
    val complete: Boolean,
)

data class TrackedAppsState(
    val registeredAppCount: Int,
    val currentPackageName: String,
    val canAddCurrentApp: Boolean,
    val canEditRegisteredApps: Boolean,
    val locked: Boolean,
)

fun resolveCareHubHealth(
    discordReady: Boolean,
    registeredAppCount: Int,
    foregroundDetectionEnabled: Boolean,
    missingPermissionCount: Int,
): CareHubHealth = when {
    !discordReady -> CareHubHealth(CareHubHealthLevel.NEEDS_ATTENTION, CareHubActionTarget.DISCORD)
    registeredAppCount == 0 -> CareHubHealth(CareHubHealthLevel.NEEDS_ATTENTION, CareHubActionTarget.TRACKED_APPS)
    missingPermissionCount > 0 -> CareHubHealth(CareHubHealthLevel.NEEDS_ATTENTION, CareHubActionTarget.PERMISSIONS)
    !foregroundDetectionEnabled -> CareHubHealth(CareHubHealthLevel.NEEDS_ATTENTION, CareHubActionTarget.TRACKED_APPS)
    else -> CareHubHealth(CareHubHealthLevel.GOOD, CareHubActionTarget.PRESENCE)
}

fun resolvePermissionSummary(
    usageGranted: Boolean,
    appNotificationGranted: Boolean,
    notificationListenerGranted: Boolean,
): PermissionSummary {
    val missingCount = listOf(
        usageGranted,
        appNotificationGranted,
        notificationListenerGranted,
    ).count { !it }
    return PermissionSummary(
        missingCount = missingCount,
        complete = missingCount == 0,
    )
}

fun resolveTrackedAppsState(
    foregroundDetectionEnabled: Boolean,
    registeredAppCount: Int,
    currentPackageName: String,
    currentPackageRegistered: Boolean,
): TrackedAppsState {
    val canEdit = foregroundDetectionEnabled
    return TrackedAppsState(
        registeredAppCount = registeredAppCount,
        currentPackageName = currentPackageName,
        canAddCurrentApp = canEdit && currentPackageName.isNotBlank() && !currentPackageRegistered,
        canEditRegisteredApps = canEdit,
        locked = !canEdit,
    )
}
