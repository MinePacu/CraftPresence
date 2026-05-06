package com.minepacu.craftpresence.core.discord

/**
 * Platform abstraction for the Discord SDK.
 *
 * Implementations may call the real native SDK, a test double, or another bridge while preserving
 * the same coroutine-friendly contract for the rest of the app.
 */
interface DiscordGateway {
    /** Initializes the SDK for the given Discord Developer Portal application ID. */
    suspend fun configure(applicationId: String)

    /** Starts interactive authorization and returns the authorized user plus refresh token. */
    suspend fun authorize(): DiscordAuthorizationResult

    /** Restores authorization by exchanging a refresh token for a new SDK token. */
    suspend fun refreshAuthorization(refreshToken: String): DiscordAuthorizationResult

    /** Returns the current authorized Discord user. */
    suspend fun currentUser(): DiscordUser

    /** Disconnects the current user and clears SDK-side authorization state. */
    suspend fun logout()

    /** Publishes a Rich Presence activity to Discord. */
    suspend fun updateActivity(activity: DiscordActivity)

    /** Removes the currently published Rich Presence activity. */
    suspend fun clearActivity()

    /** Returns `true` when the SDK has an authenticated user. */
    fun isAuthorized(): Boolean

    /** Returns `true` when the SDK is authenticated and ready to serve user data. */
    fun isConnected(): Boolean
}

/**
 * In-memory Discord gateway used for tests and previews where the native SDK is unavailable.
 */
class NoopDiscordGateway : DiscordGateway {
    private var configuredApplicationId: String? = null
    private var user: DiscordUser? = null
    private var lastActivity: DiscordActivity? = null

    override suspend fun configure(applicationId: String) {
        configuredApplicationId = applicationId
    }

    override suspend fun authorize(): DiscordAuthorizationResult {
        val applicationId = configuredApplicationId ?: throw DiscordSdkError.NotConfigured
        user = DiscordUser(id = applicationId, username = "Local Discord Bridge")
        return DiscordAuthorizationResult(requireNotNull(user), "local-refresh-token")
    }

    override suspend fun refreshAuthorization(refreshToken: String): DiscordAuthorizationResult {
        val applicationId = configuredApplicationId ?: throw DiscordSdkError.NotConfigured
        user = DiscordUser(id = applicationId, username = "Local Discord Bridge")
        return DiscordAuthorizationResult(requireNotNull(user), refreshToken)
    }

    override suspend fun currentUser(): DiscordUser {
        return user ?: throw DiscordSdkError.Unauthorized
    }

    override suspend fun logout() {
        user = null
        lastActivity = null
    }

    override suspend fun updateActivity(activity: DiscordActivity) {
        if (user == null) throw DiscordSdkError.Unauthorized
        lastActivity = activity
    }

    override suspend fun clearActivity() {
        lastActivity = null
    }

    override fun isAuthorized(): Boolean = user != null

    override fun isConnected(): Boolean = configuredApplicationId != null
}
