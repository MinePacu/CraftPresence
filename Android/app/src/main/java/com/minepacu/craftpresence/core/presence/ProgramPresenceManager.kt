package com.minepacu.craftpresence.core.presence

import android.content.Context
import com.minepacu.craftpresence.core.config.ConfigUtility
import com.minepacu.craftpresence.core.config.ProgramPresenceSettings
import com.minepacu.craftpresence.core.discord.DiscordActivity
import com.minepacu.craftpresence.core.discord.DiscordPresenceSource
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
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch

data class ProgramPresenceState(
    val isEnabled: Boolean = false,
    val activeAppName: String = "",
    val activePackageName: String = "",
    val discordStatus: String = "Not Connected",
    val lastErrorMessage: String? = null,
)

internal data class ProgramPresenceSession(
    val packageName: String,
    val payloadKey: String,
    val startEpochSeconds: Long,
)

internal fun resolveProgramPresenceSession(
    previous: ProgramPresenceSession?,
    packageName: String,
    payloadKey: String,
    resetElapsedTimeOnPresenceChange: Boolean,
    nowEpochSeconds: Long,
): ProgramPresenceSession {
    val shouldStartNewSession = previous == null ||
        previous.packageName != packageName ||
        (resetElapsedTimeOnPresenceChange && previous.payloadKey != payloadKey)

    return if (shouldStartNewSession) {
        ProgramPresenceSession(
            packageName = packageName,
            payloadKey = payloadKey,
            startEpochSeconds = nowEpochSeconds,
        )
    } else {
        previous.copy(payloadKey = payloadKey)
    }
}

class ProgramPresenceManager private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val detector = ProgramDetector.getInstance(appContext)
    private val config = ConfigUtility.getInstance(appContext)
    private val discord = DiscordSdkManager.getInstance(appContext)

    private var collectJob: Job? = null
    private var currentSession: ProgramPresenceSession? = null
    private var lastAppliedActivityKey: String? = null

    private val _state = MutableStateFlow(ProgramPresenceState())
    val state: StateFlow<ProgramPresenceState> = _state.asStateFlow()

    fun startMonitoring() {
        if (collectJob != null) return
        detector.start(DETECTOR_OWNER)
        discord.retainActivityPriority(PRIORITY_OWNER)
        collectJob = scope.launch {
            runCatching {
                discord.configure(
                    autoAuthorize = true,
                    allowInteractiveAuthorization = false,
                )
            }.onFailure { error ->
                _state.value = _state.value.copy(
                    isEnabled = true,
                    discordStatus = "Authorization Required",
                    lastErrorMessage = error.message,
                )
            }
            combine(detector.updates, config.settings) { update, _ -> update }
                .collect { update -> handleProgramUpdate(update) }
        }
        _state.value = _state.value.copy(isEnabled = true, discordStatus = "Configured", lastErrorMessage = null)
    }

    fun stopMonitoring() {
        collectJob?.cancel()
        collectJob = null
        detector.stop(DETECTOR_OWNER)
        currentSession = null
        lastAppliedActivityKey = null
        discord.releaseActivityPriority(PRIORITY_OWNER)
        scope.launch { discord.clearActivity() }
        _state.value = ProgramPresenceState(discordStatus = "Not Connected")
    }

    private suspend fun handleProgramUpdate(update: ProgramUpdate) {
        val packageName = update.packageName.orEmpty()
        val tracked = config.currentSettings().packageNames
        if (packageName.isBlank() || packageName !in tracked) {
            if (lastAppliedActivityKey != null) {
                runCatching { discord.clearActivity() }
                lastAppliedActivityKey = null
            }
            currentSession = null
            _state.value = _state.value.copy(
                activeAppName = update.appName.orEmpty(),
                activePackageName = packageName,
                discordStatus = if (packageName.isBlank()) "Idle" else "Not Tracked",
                lastErrorMessage = null,
            )
            return
        }

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
        val payloadKey = programPresencePayloadKey(
            packageName = packageName,
            appName = appName,
            state = state,
            details = detail,
            settings = settings,
        )
        val session = resolveProgramPresenceSession(
            previous = currentSession,
            packageName = packageName,
            payloadKey = payloadKey,
            resetElapsedTimeOnPresenceChange = settings.resetElapsedTimeOnPresenceChange,
            nowEpochSeconds = System.currentTimeMillis() / 1000L,
        )
        currentSession = session
        val activity = DiscordActivity(
            name = appName,
            state = state,
            details = detail,
            largeImageKey = settings.largeImageKey,
            largeImageText = settings.largeImageText,
            smallImageKey = settings.smallImageKey,
            smallImageText = settings.smallImageText,
            startEpochSeconds = session.startEpochSeconds,
            activityType = settings.activityType,
        )
        val activityKey = activity.toUpdateKey()

        runCatching {
            discord.updateActivity(activity, DiscordPresenceSource.APP)
        }.onSuccess {
            lastAppliedActivityKey = activityKey
            _state.value = ProgramPresenceState(
                isEnabled = true,
                activeAppName = appName,
                activePackageName = packageName,
                discordStatus = "Active",
                lastErrorMessage = null,
            )
        }.onFailure { error ->
            _state.value = _state.value.copy(
                discordStatus = "Update Failed",
                lastErrorMessage = error.message ?: error::class.simpleName,
            )
        }
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

    private fun programPresencePayloadKey(
        packageName: String,
        appName: String,
        state: String,
        details: String,
        settings: ProgramPresenceSettings,
    ): String = listOf(
        packageName,
        appName,
        state,
        details,
        settings.largeImageKey,
        settings.largeImageText,
        settings.smallImageKey,
        settings.smallImageText,
        settings.partyCurrent,
        settings.partyMax,
        settings.activityType,
    ).joinToString("|") { it.toString() }

    private fun DiscordActivity.toUpdateKey(): String = listOf(
        name,
        state,
        details,
        largeImageKey,
        largeImageText,
        smallImageKey,
        smallImageText,
        partyCurrent,
        partyMax,
        startEpochSeconds,
        activityType,
    ).joinToString("|") { it?.toString().orEmpty() }

    companion object {
        private const val PRIORITY_OWNER = "program-presence"
        private const val DETECTOR_OWNER = "program-presence-manager"

        @Volatile private var instance: ProgramPresenceManager? = null

        fun getInstance(context: Context): ProgramPresenceManager {
            return instance ?: synchronized(this) {
                instance ?: ProgramPresenceManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
