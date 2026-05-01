package com.minepacu.craftpresence.core.config

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject

class ConfigUtility private constructor(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        "craftpresence_settings",
        Context.MODE_PRIVATE,
    )
    private val mutex = Mutex()
    private val _settings = MutableStateFlow(load())

    val settings: StateFlow<AppSettings> = _settings.asStateFlow()

    suspend fun currentSettings(): AppSettings = mutex.withLock { _settings.value }

    suspend fun setSettings(newValue: AppSettings): AppSettings = mutex.withLock {
        persist(newValue)
        _settings.value = newValue
        newValue
    }

    suspend fun addPackageName(packageName: String, displayName: String = ""): AppSettings = mutex.withLock {
        val normalized = packageName.trim()
        val normalizedDisplayName = displayName.trim()
        if (normalized.isEmpty()) {
            return@withLock _settings.value
        }
        val packages = if (normalized in _settings.value.packageNames) {
            _settings.value.packageNames
        } else {
            (_settings.value.packageNames + normalized).sorted()
        }
        val displayNames = if (normalizedDisplayName.isBlank()) {
            _settings.value.appDisplayNames
        } else {
            _settings.value.appDisplayNames + (normalized to normalizedDisplayName)
        }
        val next = _settings.value.copy(packageNames = packages, appDisplayNames = displayNames)
        persist(next)
        _settings.value = next
        next
    }

    suspend fun removePackageName(packageName: String): AppSettings = mutex.withLock {
        val next = _settings.value.copy(
            packageNames = _settings.value.packageNames.filterNot { it == packageName },
            appDisplayNames = _settings.value.appDisplayNames - packageName,
            programSettings = _settings.value.programSettings - packageName,
        )
        persist(next)
        _settings.value = next
        next
    }

    suspend fun containsPackageName(packageName: String): Boolean = mutex.withLock {
        packageName in _settings.value.packageNames
    }

    suspend fun programSettings(packageName: String): ProgramPresenceSettings = mutex.withLock {
        _settings.value.programSettings[packageName] ?: ProgramPresenceSettings()
    }

    suspend fun appDisplayName(packageName: String): String = mutex.withLock {
        _settings.value.appDisplayNames[packageName].orEmpty()
    }

    suspend fun setAppDisplayName(packageName: String, displayName: String): AppSettings = mutex.withLock {
        val normalizedPackage = packageName.trim()
        val normalizedDisplayName = displayName.trim()
        if (normalizedPackage.isBlank()) return@withLock _settings.value
        val next = _settings.value.copy(
            appDisplayNames = if (normalizedDisplayName.isBlank()) {
                _settings.value.appDisplayNames - normalizedPackage
            } else {
                _settings.value.appDisplayNames + (normalizedPackage to normalizedDisplayName)
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
        if (packageName.isBlank()) return@withLock newValue
        val next = _settings.value.copy(
            programSettings = _settings.value.programSettings + (packageName to newValue),
        )
        persist(next)
        _settings.value = next
        newValue
    }

    private fun load(): AppSettings {
        val raw = preferences.getString(KEY_SETTINGS, null) ?: return AppSettings()
        return runCatching { AppSettings.fromJson(JSONObject(raw)) }.getOrDefault(AppSettings())
    }

    private fun persist(settings: AppSettings) {
        preferences.edit().putString(KEY_SETTINGS, settings.toJson().toString(2)).apply()
    }

    companion object {
        private const val KEY_SETTINGS = "settings"

        @Volatile private var instance: ConfigUtility? = null

        fun getInstance(context: Context): ConfigUtility {
            return instance ?: synchronized(this) {
                instance ?: ConfigUtility(context.applicationContext).also { instance = it }
            }
        }
    }
}
