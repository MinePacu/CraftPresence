package com.minepacu.craftpresence.core.discord

interface DiscordGateway {
    suspend fun configure(applicationId: String)
    suspend fun authorize(): DiscordAuthorizationResult
    suspend fun refreshAuthorization(refreshToken: String): DiscordAuthorizationResult
    suspend fun currentUser(): DiscordUser
    suspend fun logout()
    suspend fun updateActivity(activity: DiscordActivity)
    suspend fun clearActivity()
    fun isAuthorized(): Boolean
    fun isConnected(): Boolean
}

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
