package com.minepacu.craftpresence.core.config

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class ConfigUtility private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val preferences = appContext.getSharedPreferences(
        "craftpresence_settings",
        Context.MODE_PRIVATE,
    )
    private val mutex = Mutex()
    private val _settings = MutableStateFlow(load())

    val settings: StateFlow<AppSettings> = _settings.asStateFlow()

    suspend fun currentSettings(): AppSettings = mutex.withLock { loadLatest() }

    suspend fun refreshSettings(): AppSettings = mutex.withLock { loadLatest() }

    suspend fun setSettings(newValue: AppSettings): AppSettings = mutex.withLock {
        persist(newValue)
        _settings.value = newValue
        newValue
    }

    suspend fun addPackageName(packageName: String, displayName: String = ""): AppSettings = mutex.withLock {
        val current = loadLatest()
        val normalized = packageName.trim()
        val normalizedDisplayName = displayName.trim()
        if (normalized.isEmpty()) {
            return@withLock current
        }
        val packages = if (normalized in current.packageNames) {
            current.packageNames
        } else {
            (current.packageNames + normalized).sorted()
        }
        val displayNames = if (normalizedDisplayName.isBlank()) {
            current.appDisplayNames
        } else {
            current.appDisplayNames + (normalized to normalizedDisplayName)
        }
        val next = current.copy(packageNames = packages, appDisplayNames = displayNames)
        persist(next)
        _settings.value = next
        next
    }

    suspend fun removePackageName(packageName: String): AppSettings = mutex.withLock {
        val current = loadLatest()
        val next = current.copy(
            packageNames = current.packageNames.filterNot { it == packageName },
            appDisplayNames = current.appDisplayNames - packageName,
            programSettings = current.programSettings - packageName,
        )
        persist(next)
        _settings.value = next
        next
    }

    suspend fun containsPackageName(packageName: String): Boolean = mutex.withLock {
        packageName in loadLatest().packageNames
    }

    suspend fun programSettings(packageName: String): ProgramPresenceSettings = mutex.withLock {
        loadLatest().programSettings[packageName] ?: ProgramPresenceSettings()
    }

    suspend fun appDisplayName(packageName: String): String = mutex.withLock {
        loadLatest().appDisplayNames[packageName].orEmpty()
    }

    suspend fun setAppDisplayName(packageName: String, displayName: String): AppSettings = mutex.withLock {
        val current = loadLatest()
        val normalizedPackage = packageName.trim()
        val normalizedDisplayName = displayName.trim()
        if (normalizedPackage.isBlank()) return@withLock current
        val next = current.copy(
            appDisplayNames = if (normalizedDisplayName.isBlank()) {
                current.appDisplayNames - normalizedPackage
            } else {
                current.appDisplayNames + (normalizedPackage to normalizedDisplayName)
            },
        )
        persist(next)
        _settings.value = next
        next
    }

    suspend fun setProgramSettings(
        packageName: String,
        newValue: ProgramPresenceSettings,
    ): ProgramPresenceSettings = mutex.withLock {
        val current = loadLatest()
        if (packageName.isBlank()) return@withLock newValue
        val next = current.copy(
            programSettings = current.programSettings + (packageName to newValue),
        )
        persist(next)
        _settings.value = next
        newValue
    }

    suspend fun presencePresets(): List<PresencePreset> = mutex.withLock {
        loadLatest().presencePresets
    }

    suspend fun activePresencePreset(): PresencePreset? = mutex.withLock {
        val current = loadLatest()
        current.activePresencePresetID?.let { id ->
            current.presencePresets.firstOrNull { it.id == id }
        }
    }

    suspend fun upsertPresencePreset(preset: PresencePreset): PresencePreset = mutex.withLock {
        val current = loadLatest()
        val presets = if (current.presencePresets.any { it.id == preset.id }) {
            current.presencePresets.map { existing ->
                if (existing.id == preset.id) preset else existing
            }
        } else {
            current.presencePresets + preset
        }
        val next = current.copy(presencePresets = presets)
        persist(next)
        _settings.value = next
        preset
    }

    suspend fun removePresencePreset(id: String): AppSettings = mutex.withLock {
        val current = loadLatest()
        val next = current.copy(
            presencePresets = current.presencePresets.filterNot { it.id == id },
            activePresencePresetID = current.activePresencePresetID.takeIf { it != id },
            appliedPresence = current.appliedPresence.takeUnless { it?.partyID == "preset:$id" },
        )
        persist(next)
        _settings.value = next
        next
    }

    suspend fun setActivePresencePresetID(id: String?): AppSettings = mutex.withLock {
        val current = loadLatest()
        val next = current.copy(activePresencePresetID = id)
        persist(next)
        _settings.value = next
        next
    }

    suspend fun setAppliedPresence(payload: AppliedPresencePayload?): AppSettings = mutex.withLock {
        val current = loadLatest()
        val next = current.copy(appliedPresence = payload)
        persist(next)
        _settings.value = next
        next
    }

    suspend fun restoreDefaultPresencePresets(): AppSettings = mutex.withLock {
        val current = loadLatest()
        val existingIDs = current.presencePresets.map { it.id }.toSet()
        val missingDefaults = PresencePreset.defaults.filterNot { it.id in existingIDs }
        if (missingDefaults.isEmpty()) return@withLock current
        val next = current.copy(presencePresets = current.presencePresets + missingDefaults)
        persist(next)
        _settings.value = next
        next
    }

    suspend fun exportSettingsBackup(platform: String = CURRENT_BACKUP_PLATFORM): String = mutex.withLock {
        SettingsBackupFile(
            schemaVersion = SettingsBackupFile.CURRENT_SCHEMA_VERSION,
            appName = APP_NAME,
            appVersion = currentAppVersion(),
            buildNumber = currentBuildNumber(),
            exportedAt = iso8601Now(),
            platform = platform,
            settings = loadLatest(),
        ).toJson().toString(2)
    }

    suspend fun importSettingsBackup(raw: String): AppSettings = mutex.withLock {
        val backup = decodeSettingsBackup(raw)
        val next = backup.settingsForImport()
        persist(next)
        _settings.value = next
        next
    }

    private fun load(): AppSettings {
        val raw = preferences.getString(KEY_SETTINGS, null) ?: return AppSettings()
        return runCatching { AppSettings.fromJson(JSONObject(raw)) }.getOrDefault(AppSettings())
    }

    private fun loadLatest(): AppSettings {
        val latest = load()
        if (latest != _settings.value) {
            _settings.value = latest
        }
        return latest
    }

    private fun persist(settings: AppSettings) {
        preferences.edit().putString(KEY_SETTINGS, settings.toJson().toString(2)).apply()
    }

    private fun currentAppVersion(): String? = runCatching {
        currentPackageInfo().versionName
    }.getOrNull()

    private fun currentBuildNumber(): String? = runCatching {
        val packageInfo = currentPackageInfo()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            packageInfo.versionCode.toLong()
        }.toString()
    }.getOrNull()

    private fun currentPackageInfo(): PackageInfo {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.packageManager.getPackageInfo(
                appContext.packageName,
                PackageManager.PackageInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            appContext.packageManager.getPackageInfo(appContext.packageName, 0)
        }
    }

    companion object {
        private const val KEY_SETTINGS = "settings"
        private const val APP_NAME = "CraftPresence"
        private const val CURRENT_BACKUP_PLATFORM = "Android"

        @Volatile private var instance: ConfigUtility? = null

        fun getInstance(context: Context): ConfigUtility {
            return instance ?: synchronized(this) {
                instance ?: ConfigUtility(context.applicationContext).also { instance = it }
            }
        }

        fun decodeSettingsBackup(raw: String): SettingsBackupFile = SettingsBackupFile.decode(raw)

        fun defaultSettingsBackupFilename(): String {
            return "CraftPresence-Settings-${timestampForFilename()}.craftpresence.json"
        }

        private fun iso8601Now(): String {
            return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }.format(Date())
        }

        private fun timestampForFilename(): String {
            return SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).apply {
                timeZone = TimeZone.getDefault()
            }.format(Date())
        }
    }
}
