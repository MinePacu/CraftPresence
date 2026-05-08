package com.minepacu.craftpresence.core.config

import com.minepacu.craftpresence.core.discord.DiscordActivity
import org.json.JSONArray
import org.json.JSONObject

data class AppSettings(
    val packageNames: List<String> = emptyList(),
    val appDisplayNames: Map<String, String> = emptyMap(),
    val programSettings: Map<String, ProgramPresenceSettings> = emptyMap(),
    val presencePresets: List<PresencePreset> = PresencePreset.defaults,
    val activePresencePresetID: String? = null,
    val appliedPresence: AppliedPresencePayload? = null,
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
        .put("presencePresets", JSONArray(presencePresets.map { it.toJson() }))
        .put("activePresencePresetID", activePresencePresetID ?: JSONObject.NULL)
        .put("appliedPresence", appliedPresence?.toJson() ?: JSONObject.NULL)
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
            val presetArray = json.optJSONArray("presencePresets")
                ?: json.optJSONArray("customPresencePresets")
            val presets = presetArray
                ?.let { array ->
                    List(array.length()) { index ->
                        array.optJSONObject(index)?.let(PresencePreset::fromJson)
                    }.filterNotNull()
                }
                ?.takeIf { it.isNotEmpty() }
                ?: PresencePreset.defaults

            return AppSettings(
                packageNames = packages,
                appDisplayNames = displayNames,
                programSettings = settings,
                presencePresets = presets,
                activePresencePresetID = json.optNullableString("activePresencePresetID")
                    ?: json.optNullableString("activeCustomPresencePresetID"),
                appliedPresence = json.optJSONObject("appliedPresence")?.let(AppliedPresencePayload::fromJson),
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
    val presetID: String? = null,
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
        .put("activityType", activityType.sharedSchemaValue)
        .put("presetID", presetID ?: JSONObject.NULL)
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
            activityType = parseActivityType(json.optString("activityType")),
            presetID = json.optNullableString("presetID"),
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

data class PresencePreset(
    val id: String,
    val title: String,
    val activityType: DiscordActivity.ActivityType = DiscordActivity.ActivityType.PLAYING,
    val details: String = "",
    val state: String = "",
    val largeImageKey: String = "",
    val largeImageText: String = "",
    val smallImageKey: String = "",
    val smallImageText: String = "",
    val usesElapsedTime: Boolean = true,
    val resetsElapsedTimeOnPublish: Boolean = true,
    val usesParty: Boolean = false,
    val partyCurrent: Int = 1,
    val partyMax: Int = 1,
    val isDefault: Boolean = false,
    val updatedAt: String = DEFAULT_UPDATED_AT,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("title", title)
        .put("activityType", activityType.sharedSchemaValue)
        .put("details", details)
        .put("state", state)
        .put("largeImageKey", largeImageKey)
        .put("largeImageText", largeImageText)
        .put("smallImageKey", smallImageKey)
        .put("smallImageText", smallImageText)
        .put("usesElapsedTime", usesElapsedTime)
        .put("resetsElapsedTimeOnPublish", resetsElapsedTimeOnPublish)
        .put("usesParty", usesParty)
        .put("partyCurrent", partyCurrent)
        .put("partyMax", partyMax)
        .put("isDefault", isDefault)
        .put("updatedAt", updatedAt)

    fun toDiscordActivity(nowEpochSeconds: Long): DiscordActivity {
        val partyID = if (usesParty && partyCurrent > 0 && partyMax >= partyCurrent) {
            "preset:$id"
        } else {
            null
        }
        return DiscordActivity(
            name = title,
            state = state.takeIf { it.isNotBlank() },
            details = details.takeIf { it.isNotBlank() },
            largeImageKey = largeImageKey.takeIf { it.isNotBlank() },
            largeImageText = largeImageText.takeIf { it.isNotBlank() },
            smallImageKey = smallImageKey.takeIf { it.isNotBlank() },
            smallImageText = smallImageText.takeIf { it.isNotBlank() },
            partyId = partyID,
            partyCurrent = partyID?.let { partyCurrent },
            partyMax = partyID?.let { partyMax },
            startEpochSeconds = if (usesElapsedTime) nowEpochSeconds else null,
            activityType = activityType,
        )
    }

    companion object {
        private const val DEFAULT_UPDATED_AT = "2026-05-08T00:00:00.000Z"

        val defaults: List<PresencePreset> = listOf(
            PresencePreset(
                id = "00000000-0000-0000-0000-000000000001",
                title = "Coding",
                activityType = DiscordActivity.ActivityType.PLAYING,
                details = "Building CraftPresence",
                state = "Writing code",
                largeImageKey = "code",
                largeImageText = "Coding",
                isDefault = true,
            ),
            PresencePreset(
                id = "00000000-0000-0000-0000-000000000002",
                title = "Studying",
                activityType = DiscordActivity.ActivityType.WATCHING,
                details = "Studying",
                state = "Reviewing notes",
                largeImageKey = "study",
                largeImageText = "Study session",
                isDefault = true,
            ),
            PresencePreset(
                id = "00000000-0000-0000-0000-000000000003",
                title = "Focus",
                activityType = DiscordActivity.ActivityType.PLAYING,
                details = "Deep work session",
                state = "Staying focused",
                largeImageKey = "focus",
                largeImageText = "Focus mode",
                isDefault = true,
            ),
            PresencePreset(
                id = "00000000-0000-0000-0000-000000000004",
                title = "Gaming",
                activityType = DiscordActivity.ActivityType.PLAYING,
                details = "Gaming session",
                state = "In game",
                largeImageKey = "gaming",
                largeImageText = "Gaming",
                isDefault = true,
            ),
            PresencePreset(
                id = "00000000-0000-0000-0000-000000000005",
                title = "Listening",
                activityType = DiscordActivity.ActivityType.LISTENING,
                details = "Listening to music",
                state = "Now playing",
                largeImageKey = "music",
                largeImageText = "Music",
                isDefault = true,
            ),
        )

        fun fromJson(json: JSONObject): PresencePreset = PresencePreset(
            id = json.optString("id").takeIf { it.isNotBlank() } ?: java.util.UUID.randomUUID().toString(),
            title = json.optString("title"),
            activityType = parseActivityType(json.optString("activityType")),
            details = json.optString("details"),
            state = json.optString("state"),
            largeImageKey = json.optString("largeImageKey"),
            largeImageText = json.optString("largeImageText"),
            smallImageKey = json.optString("smallImageKey"),
            smallImageText = json.optString("smallImageText"),
            usesElapsedTime = json.optBoolean("usesElapsedTime", true),
            resetsElapsedTimeOnPublish = json.optBoolean("resetsElapsedTimeOnPublish", true),
            usesParty = json.optBoolean("usesParty", false),
            partyCurrent = json.optInt("partyCurrent", 1),
            partyMax = json.optInt("partyMax", 1),
            isDefault = json.optBoolean("isDefault", false),
            updatedAt = json.optString("updatedAt").takeIf { it.isNotBlank() } ?: DEFAULT_UPDATED_AT,
        )
    }
}

data class AppliedPresencePayload(
    val name: String = "",
    val state: String? = null,
    val details: String? = null,
    val largeImageKey: String? = null,
    val largeImageText: String? = null,
    val smallImageKey: String? = null,
    val smallImageText: String? = null,
    val partyID: String? = null,
    val partyCurrent: Int? = null,
    val partyMax: Int? = null,
    val startEpochSeconds: Long? = null,
    val endEpochSeconds: Long? = null,
    val activityType: DiscordActivity.ActivityType = DiscordActivity.ActivityType.PLAYING,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("name", name)
        .put("state", state ?: JSONObject.NULL)
        .put("details", details ?: JSONObject.NULL)
        .put("largeImageKey", largeImageKey ?: JSONObject.NULL)
        .put("largeImageText", largeImageText ?: JSONObject.NULL)
        .put("smallImageKey", smallImageKey ?: JSONObject.NULL)
        .put("smallImageText", smallImageText ?: JSONObject.NULL)
        .put("partyID", partyID ?: JSONObject.NULL)
        .put("partyCurrent", partyCurrent ?: JSONObject.NULL)
        .put("partyMax", partyMax ?: JSONObject.NULL)
        .put("startEpochSeconds", startEpochSeconds ?: JSONObject.NULL)
        .put("endEpochSeconds", endEpochSeconds ?: JSONObject.NULL)
        .put("activityType", activityType.sharedSchemaValue)

    companion object {
        fun fromPreset(preset: PresencePreset, nowEpochSeconds: Long): AppliedPresencePayload {
            val activity = preset.toDiscordActivity(nowEpochSeconds)
            return AppliedPresencePayload(
                name = activity.name.orEmpty(),
                state = activity.state,
                details = activity.details,
                largeImageKey = activity.largeImageKey,
                largeImageText = activity.largeImageText,
                smallImageKey = activity.smallImageKey,
                smallImageText = activity.smallImageText,
                partyID = activity.partyId,
                partyCurrent = activity.partyCurrent,
                partyMax = activity.partyMax,
                startEpochSeconds = activity.startEpochSeconds,
                endEpochSeconds = activity.endEpochSeconds,
                activityType = activity.activityType,
            )
        }

        fun fromJson(json: JSONObject): AppliedPresencePayload = AppliedPresencePayload(
            name = json.optString("name"),
            state = json.optNullableString("state"),
            details = json.optNullableString("details"),
            largeImageKey = json.optNullableString("largeImageKey"),
            largeImageText = json.optNullableString("largeImageText"),
            smallImageKey = json.optNullableString("smallImageKey"),
            smallImageText = json.optNullableString("smallImageText"),
            partyID = json.optNullableString("partyID"),
            partyCurrent = json.optNullableInt("partyCurrent"),
            partyMax = json.optNullableInt("partyMax"),
            startEpochSeconds = json.optNullableLong("startEpochSeconds"),
            endEpochSeconds = json.optNullableLong("endEpochSeconds"),
            activityType = parseActivityType(json.optString("activityType")),
        )
    }
}

private val DiscordActivity.ActivityType.sharedSchemaValue: String
    get() = when (this) {
        DiscordActivity.ActivityType.PLAYING -> "Playing"
        DiscordActivity.ActivityType.STREAMING -> "Streaming"
        DiscordActivity.ActivityType.LISTENING -> "Listening"
        DiscordActivity.ActivityType.WATCHING -> "Watching"
        DiscordActivity.ActivityType.COMPETING -> "Competing"
    }

private fun parseActivityType(value: String?): DiscordActivity.ActivityType {
    val normalized = value?.trim().orEmpty()
    return DiscordActivity.ActivityType.entries.firstOrNull { type ->
        type.name.equals(normalized, ignoreCase = true) ||
            type.sharedSchemaValue.equals(normalized, ignoreCase = true)
    } ?: DiscordActivity.ActivityType.PLAYING
}

private fun JSONObject.optNullableString(name: String): String? {
    if (!has(name) || isNull(name)) return null
    return optString(name).trim().takeIf { it.isNotBlank() }
}

private fun JSONObject.optNullableInt(name: String): Int? {
    if (!has(name) || isNull(name)) return null
    return optInt(name)
}

private fun JSONObject.optNullableLong(name: String): Long? {
    if (!has(name) || isNull(name)) return null
    return optLong(name)
}
