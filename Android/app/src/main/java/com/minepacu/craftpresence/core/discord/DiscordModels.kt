package com.minepacu.craftpresence.core.discord

/**
 * A Discord account returned after authorization.
 *
 * @property id Discord snowflake user ID.
 * @property username Display name or username reported by the SDK.
 * @property discriminator Legacy discriminator when Discord provides one.
 */
data class DiscordUser(
    val id: String,
    val username: String,
    val discriminator: String? = null,
)

/**
 * Result of a successful Discord authorization or token refresh.
 *
 * @property user Authenticated Discord user.
 * @property refreshToken Refresh token that should be persisted for silent reauthorization.
 */
data class DiscordAuthorizationResult(
    val user: DiscordUser,
    val refreshToken: String,
)

/**
 * Rich Presence payload published to Discord.
 *
 * Empty or `null` optional fields are omitted by the native bridge.
 *
 * @property name Activity title shown as the primary Rich Presence label.
 * @property state Short status line, usually the current mode or context.
 * @property details Longer status line, usually the item, track, or screen name.
 * @property largeImageKey Discord Developer Portal asset key for the large image.
 * @property largeImageText Tooltip text for the large image.
 * @property smallImageKey Discord Developer Portal asset key for the small image.
 * @property smallImageText Tooltip text for the small image.
 * @property partyId Stable party identifier used when showing party size.
 * @property partyCurrent Current party size.
 * @property partyMax Maximum party size.
 * @property startEpochSeconds Start timestamp in Unix seconds.
 * @property endEpochSeconds End timestamp in Unix seconds.
 * @property activityType Discord activity category.
 */
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
    /** Discord Rich Presence activity category. */
    enum class ActivityType {
        PLAYING,
        STREAMING,
        LISTENING,
        WATCHING,
        COMPETING,
    }
}

/** Errors raised by the Discord SDK integration layer. */
sealed class DiscordSdkError(message: String, cause: Throwable? = null) : Exception(message, cause) {
    /** The configured Discord application ID is missing, still a placeholder, or malformed. */
    class InvalidApplicationId(message: String) : DiscordSdkError(message)

    /** `configure` must succeed before using authorization or presence APIs. */
    data object NotConfigured : DiscordSdkError("Discord application ID is not configured.")

    /** No valid Discord authorization is available for the current application ID. */
    data object Unauthorized : DiscordSdkError("Discord is not authorized.")

    /** Native Discord SDK call failed. */
    class Sdk(message: String, cause: Throwable? = null) : DiscordSdkError(message, cause)
}

/** High-level Discord authorization state exposed to UI. */
enum class DiscordAuthorizationStatus {
    AUTHORIZED,
    UNAUTHORIZED,
    UNKNOWN,
}

/** User-facing SDK lifecycle state for dashboard rendering. */
enum class DiscordDashboardStatus {
    NOT_CONFIGURED,
    CONFIGURED,
    AUTHORIZING,
    CONNECTING,
    READY,
    UNAUTHORIZED,
    FAILED,
}

/** Owner category for the Rich Presence activity most recently published by the app. */
enum class DiscordPresenceSource {
    NONE,
    APP,
    MUSIC,
    UNKNOWN,
}

/**
 * Observable Discord SDK state consumed by UI and presence features.
 *
 * @property authorizationStatus Current authorization state.
 * @property currentUser Authorized user, when available.
 * @property dashboardStatus Current setup, authorization, or connection state.
 * @property lastErrorMessage Last user-facing error message, if any.
 * @property currentActivity Last Rich Presence activity published through this manager, if active.
 * @property currentActivitySource Presence owner that published [currentActivity].
 */
data class DiscordState(
    val authorizationStatus: DiscordAuthorizationStatus = DiscordAuthorizationStatus.UNKNOWN,
    val currentUser: DiscordUser? = null,
    val dashboardStatus: DiscordDashboardStatus = DiscordDashboardStatus.NOT_CONFIGURED,
    val lastErrorMessage: String? = null,
    val currentActivity: DiscordActivity? = null,
    val currentActivitySource: DiscordPresenceSource = DiscordPresenceSource.NONE,
)
