package com.minepacu.craftpresence.core.config

import com.minepacu.craftpresence.core.discord.DiscordActivity
import org.json.JSONArray
import org.json.JSONObject

data class AppSettings(
    val packageNames: List<String> = emptyList(),
    val appDisplayNames: Map<String, String> = emptyMap(),
    val programSettings: Map<String, ProgramPresenceSettings> = emptyMap(),
    val preferredLanguage: AppLanguage = AppLanguage.SYSTEM,
    val programPresenceEnabled: Boolean = true,
    val showForegroundAppIndicator: Boolean = true,
    val showForegroundAppNotification: Boolean = false,
    val hasCompletedDiscordOnboarding: Boolean = false,
    val resetElapsedTimeOnScheduledPresetRestore: Boolean = false,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("packageNames", JSONArray(packageNames))
        .put("preferredLanguage", preferredLanguage.value)
        .put("programPresenceEnabled", programPresenceEnabled)
        .put("showForegroundAppIndicator", showForegroundAppIndicator)
        .put("showForegroundAppNotification", showForegroundAppNotification)
        .put("hasCompletedDiscordOnboarding", hasCompletedDiscordOnboarding)
        .put("resetElapsedTimeOnScheduledPresetRestore", resetElapsedTimeOnScheduledPresetRestore)
        .put(
            "appDisplayNames",
            JSONObject().also { root ->
                appDisplayNames.forEach { (key, value) -> root.put(key, value) }
            },
        )
        .put(
            "programSettings",
            JSONObject().also { root ->
                programSettings.forEach { (key, value) -> root.put(key, value.toJson()) }
            },
        )

    companion object {
        fun fromJson(json: JSONObject): AppSettings {
            val packages = json.optJSONArray("packageNames")
                ?.let { array -> List(array.length()) { array.optString(it) }.filter { it.isNotBlank() } }
                .orEmpty()

            val displayNamesJson = json.optJSONObject("appDisplayNames") ?: JSONObject()
            val displayNames = buildMap {
                val keys = displayNamesJson.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val value = displayNamesJson.optString(key).trim()
                    if (key.isNotBlank() && value.isNotBlank()) put(key, value)
                }
            }

            val settingsJson = json.optJSONObject("programSettings") ?: JSONObject()
            val settings = buildMap {
                val keys = settingsJson.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    settingsJson.optJSONObject(key)?.let { put(key, ProgramPresenceSettings.fromJson(it)) }
                }
            }

            return AppSettings(
                packageNames = packages,
                appDisplayNames = displayNames,
                programSettings = settings,
                preferredLanguage = AppLanguage.fromValue(json.optString("preferredLanguage")),
                programPresenceEnabled = json.optBoolean("programPresenceEnabled", true),
                showForegroundAppIndicator = json.optBoolean("showForegroundAppIndicator", true),
                showForegroundAppNotification = json.optBoolean("showForegroundAppNotification", false),
                hasCompletedDiscordOnboarding = json.optBoolean("hasCompletedDiscordOnboarding", false),
                resetElapsedTimeOnScheduledPresetRestore = json.optBoolean("resetElapsedTimeOnScheduledPresetRestore", false),
            )
        }
    }
}

enum class AppLanguage(val value: String) {
    SYSTEM("system"),
    KOREAN("ko"),
    ENGLISH("en"),
    JAPANESE("ja");

    companion object {
        fun fromValue(value: String?): AppLanguage = entries.firstOrNull { it.value == value } ?: SYSTEM
    }
}

data class ProgramPresenceSettings(
    val activityType: DiscordActivity.ActivityType = DiscordActivity.ActivityType.PLAYING,
    val detailText: String = "",
    val stateText: String = "",
    val useAppIconForLargeImage: Boolean = true,
    val largeImageKey: String = "",
    val largeImageText: String = "",
    val smallImageKey: String = "",
    val smallImageText: String = "",
    val resetElapsedTimeOnPresenceChange: Boolean = true,
    val partyCurrent: Int = 1,
    val partyMax: Int = 1,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("activityType", activityType.name)
        .put("detailText", detailText)
        .put("stateText", stateText)
        .put("useAppIconForLargeImage", useAppIconForLargeImage)
        .put("largeImageKey", largeImageKey)
        .put("largeImageText", largeImageText)
        .put("smallImageKey", smallImageKey)
        .put("smallImageText", smallImageText)
        .put("resetElapsedTimeOnPresenceChange", resetElapsedTimeOnPresenceChange)
        .put("partyCurrent", partyCurrent)
        .put("partyMax", partyMax)

    companion object {
        fun fromJson(json: JSONObject): ProgramPresenceSettings = ProgramPresenceSettings(
            activityType = runCatching {
                DiscordActivity.ActivityType.valueOf(json.optString("activityType"))
            }.getOrDefault(DiscordActivity.ActivityType.PLAYING),
            detailText = json.optString("detailText"),
            stateText = json.optString("stateText"),
            useAppIconForLargeImage = json.optBoolean("useAppIconForLargeImage", true),
            largeImageKey = json.optString("largeImageKey"),
            largeImageText = json.optString("largeImageText"),
            smallImageKey = json.optString("smallImageKey"),
            smallImageText = json.optString("smallImageText"),
            resetElapsedTimeOnPresenceChange = json.optBoolean("resetElapsedTimeOnPresenceChange", true),
            partyCurrent = json.optInt("partyCurrent", 1),
            partyMax = json.optInt("partyMax", 1),
        )
    }
}
