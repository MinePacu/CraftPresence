package com.minepacu.craftpresence.core.discord

import android.content.Context

/** Persists Discord refresh tokens per application ID using private app preferences. */
class DiscordTokenStore(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        "craftpresence_discord_tokens",
        Context.MODE_PRIVATE,
    )

    /** Returns the saved refresh token for an application ID, or an empty string. */
    fun refreshToken(applicationId: String): String = preferences.getString(key(applicationId), null).orEmpty()

    /** Saves a non-empty refresh token for later silent reauthorization. */
    fun setRefreshToken(applicationId: String, refreshToken: String) {
        val normalizedToken = refreshToken.trim()
        if (normalizedToken.isBlank()) return
        preferences.edit().putString(key(applicationId), normalizedToken).apply()
    }

    /** Clears one application's refresh token, or all saved tokens when no ID is supplied. */
    fun clearRefreshToken(applicationId: String? = null) {
        if (applicationId.isNullOrBlank()) {
            preferences.edit().clear().apply()
        } else {
            preferences.edit().remove(key(applicationId)).apply()
        }
    }

    private fun key(applicationId: String): String = "refresh_token_${applicationId.trim()}"
}
