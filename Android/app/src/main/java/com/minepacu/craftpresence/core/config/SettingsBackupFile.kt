package com.minepacu.craftpresence.core.config

import org.json.JSONObject

data class SettingsBackupFile(
    val schemaVersion: Int,
    val appName: String,
    val appVersion: String?,
    val buildNumber: String?,
    val exportedAt: String,
    val platform: String,
    val settings: AppSettings,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("schemaVersion", schemaVersion)
        .put("appName", appName)
        .put("appVersion", appVersion ?: JSONObject.NULL)
        .put("buildNumber", buildNumber ?: JSONObject.NULL)
        .put("exportedAt", exportedAt)
        .put("platform", platform)
        .put("settings", settings.toJson())

    fun settingsForImport(): AppSettings = when (schemaVersion) {
        CURRENT_SCHEMA_VERSION -> settings
        else -> settings
    }

    companion object {
        const val MINIMUM_SUPPORTED_SCHEMA_VERSION = 1
        const val CURRENT_SCHEMA_VERSION = 1
        private const val LEGACY_EXPORTED_AT = "1970-01-01T00:00:00.000Z"

        fun decode(raw: String): SettingsBackupFile {
            val root = JSONObject(raw)
            if (!root.has("schemaVersion") || !root.has("settings")) {
                return legacy(AppSettings.fromJson(root))
            }

            val backup = SettingsBackupFile(
                schemaVersion = root.optInt("schemaVersion", 0),
                appName = root.optString("appName", "CraftPresence"),
                appVersion = root.optNullableString("appVersion"),
                buildNumber = root.optNullableString("buildNumber"),
                exportedAt = root.optString("exportedAt"),
                platform = root.optString("platform"),
                settings = AppSettings.fromJson(
                    root.optJSONObject("settings")
                        ?: throw IllegalArgumentException("Settings backup is missing the settings object."),
                ),
            )
            backup.validate()
            return backup
        }

        fun legacy(settings: AppSettings): SettingsBackupFile = SettingsBackupFile(
            schemaVersion = CURRENT_SCHEMA_VERSION,
            appName = "CraftPresence",
            appVersion = null,
            buildNumber = null,
            exportedAt = LEGACY_EXPORTED_AT,
            platform = "legacy",
            settings = settings,
        )
    }

    private fun validate() {
        if (schemaVersion !in MINIMUM_SUPPORTED_SCHEMA_VERSION..CURRENT_SCHEMA_VERSION) {
            throw IllegalArgumentException("Unsupported settings backup schema version: $schemaVersion.")
        }

        if (platform != "Android" && platform != "legacy") {
            throw IllegalArgumentException("Unsupported settings backup platform: $platform.")
        }

        val normalizedPackages = settings.packageNames.map { it.trim() }
        val duplicatePackage = normalizedPackages
            .filter { it.isNotBlank() }
            .groupingBy { it }
            .eachCount()
            .firstNotNullOfOrNull { (packageName, count) -> packageName.takeIf { count > 1 } }
        if (duplicatePackage != null) {
            throw IllegalArgumentException("Settings backup contains a duplicate package: $duplicatePackage.")
        }

        settings.programSettings.keys.firstOrNull { it.isBlank() }?.let {
            throw IllegalArgumentException("Settings backup contains an empty package key.")
        }
    }
}

private fun JSONObject.optNullableString(name: String): String? {
    if (!has(name) || isNull(name)) return null
    return optString(name).takeIf { it.isNotBlank() }
}
