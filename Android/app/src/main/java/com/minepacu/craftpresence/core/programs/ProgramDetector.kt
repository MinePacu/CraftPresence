package com.minepacu.craftpresence.core.programs

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import com.minepacu.craftpresence.core.util.LruMemoryCache
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class ProgramDetector(context: Context) {
    private val appContext = context.applicationContext
    private val usageStatsManager = appContext.getSystemService(UsageStatsManager::class.java)
    private val packageManager = appContext.packageManager
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val labelCache = LruMemoryCache<String, String>(capacity = 120)

    private var pollingIntervalMs: Long = 2_000L
    private var pollingJob: Job? = null
    private var lastPermissionCheckMs: Long = 0L
    private var lastPermissionResult: Boolean = false

    private val _updates = MutableStateFlow(ProgramUpdate())
    val updates: StateFlow<ProgramUpdate> = _updates.asStateFlow()

    fun setPollingInterval(intervalMs: Long) {
        pollingIntervalMs = intervalMs.coerceAtLeast(500L)
        if (pollingJob != null) {
            stop()
            start()
        }
    }

    fun start() {
        if (pollingJob != null) return
        pollingJob = scope.launch {
            while (isActive) {
                refresh()
                delay(pollingIntervalMs)
            }
        }
    }

    fun stop() {
        pollingJob?.cancel()
        pollingJob = null
    }

    fun hasUsageAccess(): Boolean {
        val now = System.currentTimeMillis()
        if (now - lastPermissionCheckMs < PERMISSION_CHECK_TTL_MS) {
            return lastPermissionResult
        }

        val appOps = appContext.getSystemService(AppOpsManager::class.java)
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            @Suppress("DEPRECATION")
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                appContext.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                appContext.packageName,
            )
        }
        return (mode == AppOpsManager.MODE_ALLOWED).also {
            lastPermissionCheckMs = now
            lastPermissionResult = it
        }
    }

    private fun refresh() {
        if (!hasUsageAccess()) {
            publishIfChanged(ProgramUpdate())
            return
        }

        val now = System.currentTimeMillis()
        val events = usageStatsManager.queryEvents(now - LOOKBACK_MS, now)
        val event = UsageEvents.Event()
        var foregroundPackage: String? = null
        var foregroundTime = 0L

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val foregroundEventType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                UsageEvents.Event.ACTIVITY_RESUMED
            } else {
                @Suppress("DEPRECATION")
                UsageEvents.Event.MOVE_TO_FOREGROUND
            }
            if (event.eventType == foregroundEventType && event.timeStamp >= foregroundTime) {
                foregroundPackage = event.packageName
                foregroundTime = event.timeStamp
            }
        }

        publishIfChanged(ProgramUpdate(
            appName = foregroundPackage?.let(::labelForPackage),
            packageName = foregroundPackage,
            windowTitle = null,
        ))
    }

    private fun publishIfChanged(update: ProgramUpdate) {
        if (_updates.value != update) {
            _updates.value = update
        }
    }

    private fun labelForPackage(packageName: String): String {
        labelCache.get(packageName)?.let { return it }
        return runCatching {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        }.getOrDefault(packageName).also {
            labelCache.put(packageName, it)
        }
    }

    companion object {
        private const val LOOKBACK_MS = 20_000L
        private const val PERMISSION_CHECK_TTL_MS = 10_000L

        @Volatile private var instance: ProgramDetector? = null

        fun getInstance(context: Context): ProgramDetector {
            return instance ?: synchronized(this) {
                instance ?: ProgramDetector(context.applicationContext).also { instance = it }
            }
        }
    }
}
