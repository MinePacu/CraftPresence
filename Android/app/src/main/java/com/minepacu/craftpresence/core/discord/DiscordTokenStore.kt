package com.minepacu.craftpresence.core.discord

import android.content.Context

class DiscordTokenStore(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        "craftpresence_discord_tokens",
        Context.MODE_PRIVATE,
    )

    fun refreshToken(applicationId: String): String = preferences.getString(key(applicationId), null).orEmpty()

    fun setRefreshToken(applicationId: String, refreshToken: String) {
        val normalizedToken = refreshToken.trim()
        if (normalizedToken.isBlank()) return
        preferences.edit().putString(key(applicationId), normalizedToken).apply()
    }

    fun clearRefreshToken(applicationId: String? = null) {
        if (applicationId.isNullOrBlank()) {
            preferences.edit().clear().apply()
        } else {
            preferences.edit().remove(key(applicationId)).apply()
        }
    }

    private fun key(applicationId: String): String = "refresh_token_${applicationId.trim()}"
}
