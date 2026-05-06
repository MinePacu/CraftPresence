package com.minepacu.craftpresence.core.discord

/**
 * JNI boundary for the bundled Discord Partner SDK.
 *
 * Each method mirrors a native function in `DiscordBridge.cpp`. String return values represent
 * errors; `null` means success.
 */
internal object NativeDiscordBridge {
    init {
        System.loadLibrary("craftpresence_discord")
    }

    /** Initializes the native Discord client for the provided application ID. */
    external fun configure(applicationId: String): String?

    /** Runs interactive OAuth authorization and returns `[success, id, username, error, refreshToken]`. */
    external fun authorize(): Array<String>

    /** Refreshes authorization and returns `[success, id, username, error, refreshToken]`. */
    external fun refreshAuthorization(refreshToken: String): Array<String>

    /** Returns `[success, id, username, error, refreshToken]` for the current SDK user. */
    external fun currentUser(): Array<String>

    /** Disconnects the native Discord client. */
    external fun logout(): String?

    /** Publishes a Rich Presence activity through the native SDK. */
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

    /** Clears the current Rich Presence activity. */
    external fun clearActivity(): String?

    /** Returns whether the native SDK has an authenticated user. */
    external fun isAuthorized(): Boolean

    /** Returns whether the authenticated SDK session is ready for user and presence calls. */
    external fun isConnected(): Boolean
}
