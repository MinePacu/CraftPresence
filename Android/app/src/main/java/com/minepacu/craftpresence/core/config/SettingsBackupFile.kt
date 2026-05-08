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
    val platformExtensions: JSONObject = JSONObject(),
) {
    fun toJson(): JSONObject = JSONObject()
        .put("schemaVersion", schemaVersion)
        .put("appName", appName)
        .put("appVersion", appVersion ?: JSONObject.NULL)
        .put("buildNumber", buildNumber ?: JSONObject.NULL)
        .put("exportedAt", exportedAt)
        .put("platform", platform)
        .put("settings", settings.toJson())
        .put("platformExtensions", platformExtensions)

    fun settingsForImport(): AppSettings = when (schemaVersion) {
        CURRENT_SCHEMA_VERSION -> settings
        else -> settings
    }

    fun importSummary(): SettingsImportSummary = SettingsImportSummary(
        schemaVersion = schemaVersion,
        platform = platform,
        exportedAt = exportedAt,
        presetCount = settings.presencePresets.size,
        trackedProgramCount = settings.packageNames.size,
        language = settings.preferredLanguage.value,
        ignoredPlatformExtensionKeys = platformExtensions.keys().asSequence().toList().sorted(),
    )

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
                platformExtensions = root.optJSONObject("platformExtensions") ?: JSONObject(),
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
            platformExtensions = JSONObject(),
        )
    }

    private fun validate() {
        if (schemaVersion !in MINIMUM_SUPPORTED_SCHEMA_VERSION..CURRENT_SCHEMA_VERSION) {
            throw IllegalArgumentException("Unsupported settings backup schema version: $schemaVersion.")
        }

        if (platform != "Android" && platform != "iOS" && platform != "macOS" && platform != "legacy") {
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

        val presetIDs = settings.presencePresets.map { it.id.trim() }
        val duplicatePreset = presetIDs
            .filter { it.isNotBlank() }
            .groupingBy { it }
            .eachCount()
            .firstNotNullOfOrNull { (presetID, count) -> presetID.takeIf { count > 1 } }
        if (duplicatePreset != null) {
            throw IllegalArgumentException("Settings backup contains a duplicate Presence preset: $duplicatePreset.")
        }

        if (settings.activePresencePresetID != null && settings.activePresencePresetID !in presetIDs) {
            throw IllegalArgumentException("Settings backup references a missing active Presence preset: ${settings.activePresencePresetID}.")
        }
    }
}

data class SettingsImportSummary(
    val schemaVersion: Int,
    val platform: String,
    val exportedAt: String,
    val presetCount: Int,
    val trackedProgramCount: Int,
    val language: String,
    val ignoredPlatformExtensionKeys: List<String>,
)

private fun JSONObject.optNullableString(name: String): String? {
    if (!has(name) || isNull(name)) return null
    return optString(name).takeIf { it.isNotBlank() }
}
