package com.minepacu.craftpresence.core.discord

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class AndroidDiscordGateway : DiscordGateway {
    override suspend fun configure(applicationId: String): Unit = withContext(Dispatchers.IO) {
        NativeDiscordBridge.configure(applicationId)?.let { throw DiscordSdkError.Sdk(it) }
    }

    override suspend fun authorize(): DiscordUser = withContext(Dispatchers.IO) {
        NativeDiscordBridge.authorize().toDiscordUser()
    }

    override suspend fun currentUser(): DiscordUser = withContext(Dispatchers.IO) {
        NativeDiscordBridge.currentUser().toDiscordUser()
    }

    override suspend fun logout(): Unit = withContext(Dispatchers.IO) {
        NativeDiscordBridge.logout()?.let { throw DiscordSdkError.Sdk(it) }
    }

    override suspend fun updateActivity(activity: DiscordActivity): Unit = withContext(Dispatchers.IO) {
        NativeDiscordBridge.updateActivity(
            name = activity.name,
            state = activity.state,
            details = activity.details,
            largeImageKey = activity.largeImageKey,
            largeImageText = activity.largeImageText,
            smallImageKey = activity.smallImageKey,
            smallImageText = activity.smallImageText,
            partyId = activity.partyId,
            partyCurrent = activity.partyCurrent ?: 0,
            partyMax = activity.partyMax ?: 0,
            startEpochSeconds = activity.startEpochSeconds ?: 0L,
            endEpochSeconds = activity.endEpochSeconds ?: 0L,
            activityType = activity.activityType.toNativeValue(),
        )?.let { throw DiscordSdkError.Sdk(it) }
    }

    override suspend fun clearActivity(): Unit = withContext(Dispatchers.IO) {
        NativeDiscordBridge.clearActivity()?.let { throw DiscordSdkError.Sdk(it) }
    }

    override fun isAuthorized(): Boolean = NativeDiscordBridge.isAuthorized()

    override fun isConnected(): Boolean = NativeDiscordBridge.isConnected()

    private fun Array<String>.toDiscordUser(): DiscordUser {
        val success = getOrNull(0) == "true"
        if (!success) throw DiscordSdkError.Sdk(getOrNull(3).orEmpty().ifBlank { "Discord SDK call failed." })
        return DiscordUser(
            id = getOrNull(1).orEmpty(),
            username = getOrNull(2).orEmpty(),
        )
    }

    private fun DiscordActivity.ActivityType.toNativeValue(): Int = when (this) {
        DiscordActivity.ActivityType.PLAYING -> 0
        DiscordActivity.ActivityType.STREAMING -> 1
        DiscordActivity.ActivityType.LISTENING -> 2
        DiscordActivity.ActivityType.WATCHING -> 3
        DiscordActivity.ActivityType.COMPETING -> 5
    }
}
