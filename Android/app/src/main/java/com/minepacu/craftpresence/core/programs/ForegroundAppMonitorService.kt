package com.minepacu.craftpresence.core.programs

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.minepacu.craftpresence.MainActivity
import com.minepacu.craftpresence.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

class ForegroundAppMonitorService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private lateinit var detector: ProgramDetector
    private var monitorJob: Job? = null

    override fun onCreate() {
        super.onCreate()
        detector = ProgramDetector.getInstance(applicationContext)
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        promote(detector.updates.value)
        startMonitoring()
        return START_STICKY
    }

    override fun onDestroy() {
        monitorJob?.cancel()
        monitorJob = null
        detector.stop(DETECTOR_OWNER)
        scope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startMonitoring() {
        if (monitorJob != null) return
        detector.start(DETECTOR_OWNER)
        monitorJob = scope.launch {
            detector.updates.collectLatest { update ->
                promote(update)
            }
        }
    }

    @SuppressLint("InlinedApi")
    private fun promote(update: ProgramUpdate) {
        val notification = buildNotification(update)
        val foregroundServiceType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, notification, foregroundServiceType)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        }.onFailure {
            stopSelf()
        }
    }

    private fun buildNotification(update: ProgramUpdate): Notification {
        val packageName = update.packageName.orEmpty()
        val appName = update.appName?.takeIf { it.isNotBlank() } ?: packageName
        val contentText = when {
            appName.isNotBlank() -> "Current app: $appName"
            detector.hasUsageAccess() -> "Monitoring foreground apps"
            else -> "Usage access is required"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("CraftPresence")
            .setContentText(contentText)
            .setSubText(packageName.takeIf { it.isNotBlank() })
            .setContentIntent(contentIntent())
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Foreground app monitoring",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps foreground app detection running for Presence updates."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun contentIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java)
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        private const val CHANNEL_ID = "foreground_app_monitor"
        private const val NOTIFICATION_ID = 2002
        private const val DETECTOR_OWNER = "foreground-app-monitor-service"

        fun setEnabled(context: Context, enabled: Boolean) {
            val appContext = context.applicationContext
            val intent = Intent(appContext, ForegroundAppMonitorService::class.java)
            if (enabled) {
                ContextCompat.startForegroundService(appContext, intent)
            } else {
                appContext.stopService(intent)
            }
        }
    }
}
