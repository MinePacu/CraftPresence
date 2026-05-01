package com.minepacu.craftpresence.core.presence

import android.content.Context
import com.minepacu.craftpresence.core.config.ConfigUtility
import com.minepacu.craftpresence.core.discord.DiscordActivity
import com.minepacu.craftpresence.core.discord.DiscordSdkManager
import com.minepacu.craftpresence.core.programs.ProgramDetector
import com.minepacu.craftpresence.core.programs.ProgramUpdate
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ProgramPresenceState(
    val isEnabled: Boolean = false,
    val activeAppName: String = "",
    val activePackageName: String = "",
    val discordStatus: String = "Not Connected",
)

class ProgramPresenceManager private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val detector = ProgramDetector.getInstance(appContext)
    private val config = ConfigUtility.getInstance(appContext)
    private val discord = DiscordSdkManager.getInstance(appContext)

    private var collectJob: Job? = null
    private var currentSessionIdentifier: String? = null
    private var currentSessionStartEpochSeconds: Long? = null

    private val _state = MutableStateFlow(ProgramPresenceState())
    val state: StateFlow<ProgramPresenceState> = _state.asStateFlow()

    fun startMonitoring() {
        if (collectJob != null) return
        detector.start()
        collectJob = scope.launch {
            discord.configure(autoAuthorize = false)
            detector.updates.collect { update -> handleProgramUpdate(update) }
        }
        _state.value = _state.value.copy(isEnabled = true, discordStatus = "Configured")
    }

    fun stopMonitoring() {
        collectJob?.cancel()
        collectJob = null
        detector.stop()
        currentSessionIdentifier = null
        currentSessionStartEpochSeconds = null
        scope.launch { discord.clearActivity() }
        _state.value = ProgramPresenceState(discordStatus = "Not Connected")
    }

    private suspend fun handleProgramUpdate(update: ProgramUpdate) {
        val packageName = update.packageName.orEmpty()
        val tracked = config.currentSettings().packageNames
        if (packageName.isBlank() || packageName !in tracked) {
            _state.value = _state.value.copy(
                activeAppName = update.appName.orEmpty(),
                activePackageName = packageName,
                discordStatus = if (packageName.isBlank()) "Idle" else "Not Tracked",
            )
            return
        }

        updateSession(packageName)
        val settings = config.programSettings(packageName)
        val appName = config.appDisplayName(packageName).ifBlank { update.appName ?: packageName }
        val detail = renderPresenceText(
            template = settings.detailText.ifBlank { "{app} 앱 사용 중" },
            appName = appName,
            packageName = packageName,
            windowTitle = update.windowTitle,
        )
        val state = renderPresenceText(
            template = settings.stateText.ifBlank { update.windowTitle ?: "사용 중" },
            appName = appName,
            packageName = packageName,
            windowTitle = update.windowTitle,
        )

        runCatching {
            discord.updateActivity(
                DiscordActivity(
                    name = appName,
                    state = state,
                    details = detail,
                    largeImageKey = settings.largeImageKey,
                    largeImageText = settings.largeImageText,
                    smallImageKey = settings.smallImageKey,
                    smallImageText = settings.smallImageText,
                    partyCurrent = settings.partyCurrent,
                    partyMax = settings.partyMax,
                    startEpochSeconds = currentSessionStartEpochSeconds,
                    activityType = settings.activityType,
                ),
            )
        }.onSuccess {
            _state.value = ProgramPresenceState(
                isEnabled = true,
                activeAppName = appName,
                activePackageName = packageName,
                discordStatus = "Active",
            )
        }.onFailure {
            _state.value = _state.value.copy(discordStatus = "Update Failed")
        }
    }

    private fun updateSession(packageName: String) {
        if (currentSessionIdentifier == packageName) return
        currentSessionIdentifier = packageName
        currentSessionStartEpochSeconds = System.currentTimeMillis() / 1000L
    }

    private fun renderPresenceText(
        template: String,
        appName: String,
        packageName: String,
        windowTitle: String?,
    ): String {
        return template
            .replace("{app}", appName)
            .replace("{package}", packageName)
            .replace("{title}", windowTitle.orEmpty())
            .trim()
    }

    companion object {
        @Volatile private var instance: ProgramPresenceManager? = null

        fun getInstance(context: Context): ProgramPresenceManager {
            return instance ?: synchronized(this) {
                instance ?: ProgramPresenceManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
