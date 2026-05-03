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
