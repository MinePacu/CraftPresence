package com.minepacu.craftpresence.core.discord

internal object NativeDiscordBridge {
    init {
        System.loadLibrary("craftpresence_discord")
    }

    external fun configure(applicationId: String): String?
    external fun authorize(): Array<String>
    external fun currentUser(): Array<String>
    external fun logout(): String?
    external fun updateActivity(
        name: String?,
        state: String?,
        details: String?,
        largeImageKey: String?,
        largeImageText: String?,
        smallImageKey: String?,
        smallImageText: String?,
        partyId: String?,
        partyCurrent: Int,
        partyMax: Int,
        startEpochSeconds: Long,
        endEpochSeconds: Long,
        activityType: Int,
    ): String?
    external fun clearActivity(): String?
    external fun isAuthorized(): Boolean
    external fun isConnected(): Boolean
}
