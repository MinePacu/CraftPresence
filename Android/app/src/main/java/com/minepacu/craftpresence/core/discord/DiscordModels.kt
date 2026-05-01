package com.minepacu.craftpresence.core.discord

data class DiscordUser(
    val id: String,
    val username: String,
    val discriminator: String? = null,
)

data class DiscordActivity(
    val name: String? = null,
    val state: String? = null,
    val details: String? = null,
    val largeImageKey: String? = null,
    val largeImageText: String? = null,
    val smallImageKey: String? = null,
    val smallImageText: String? = null,
    val partyId: String? = null,
    val partyCurrent: Int? = null,
    val partyMax: Int? = null,
    val startEpochSeconds: Long? = null,
    val endEpochSeconds: Long? = null,
    val activityType: ActivityType = ActivityType.PLAYING,
) {
    enum class ActivityType {
        PLAYING,
        STREAMING,
        LISTENING,
        WATCHING,
        COMPETING,
    }
}

sealed class DiscordSdkError(message: String, cause: Throwable? = null) : Exception(message, cause) {
    class InvalidApplicationId(message: String) : DiscordSdkError(message)
    data object NotConfigured : DiscordSdkError("Discord application ID is not configured.")
    data object Unauthorized : DiscordSdkError("Discord is not authorized.")
    class Sdk(message: String, cause: Throwable? = null) : DiscordSdkError(message, cause)
}

enum class DiscordAuthorizationStatus {
    AUTHORIZED,
    UNAUTHORIZED,
    UNKNOWN,
}

enum class DiscordDashboardStatus {
    NOT_CONFIGURED,
    CONFIGURED,
    AUTHORIZING,
    CONNECTING,
    READY,
    UNAUTHORIZED,
    FAILED,
}

data class DiscordState(
    val authorizationStatus: DiscordAuthorizationStatus = DiscordAuthorizationStatus.UNKNOWN,
    val currentUser: DiscordUser? = null,
    val dashboardStatus: DiscordDashboardStatus = DiscordDashboardStatus.NOT_CONFIGURED,
    val lastErrorMessage: String? = null,
)
