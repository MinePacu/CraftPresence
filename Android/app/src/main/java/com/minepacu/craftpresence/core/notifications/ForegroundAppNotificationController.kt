package com.minepacu.craftpresence.core.notifications

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.minepacu.craftpresence.MainActivity
import com.minepacu.craftpresence.R
import com.minepacu.craftpresence.core.permissions.PermissionService
import com.minepacu.craftpresence.core.programs.ProgramDetector
import com.minepacu.craftpresence.core.programs.ProgramUpdate
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class ForegroundAppNotificationController private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val detector = ProgramDetector.getInstance(appContext)
    private val permissions = PermissionService(appContext)
    private val notificationManager = NotificationManagerCompat.from(appContext)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private var notificationJob: Job? = null
    private var lastPackageName: String? = null

    fun start() {
        if (notificationJob != null) return
        ensureNotificationChannel()
        notificationJob = scope.launch {
            detector.updates.collect { update ->
                publish(update)
            }
        }
    }

    fun stop() {
        notificationJob?.cancel()
        notificationJob = null
        lastPackageName = null
        notificationManager.cancel(NOTIFICATION_ID)
    }

    @SuppressLint("MissingPermission")
    private fun publish(update: ProgramUpdate) {
        if (!permissions.hasPostNotificationsAccess()) {
            notificationManager.cancel(NOTIFICATION_ID)
            return
        }

        val packageName = update.packageName.orEmpty()
        if (packageName == lastPackageName) return
        lastPackageName = packageName

        val appName = update.appName?.takeIf { it.isNotBlank() } ?: packageName
        if (appName.isBlank()) {
            notificationManager.cancel(NOTIFICATION_ID)
            return
        }

        val notification = NotificationCompat.Builder(appContext, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle("Current foreground app")
            .setContentText(appName)
            .setSubText(packageName.takeIf { it.isNotBlank() })
            .setContentIntent(contentIntent())
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = appContext.getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Foreground app status",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows the app currently detected in the foreground."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun contentIntent(): PendingIntent {
        val intent = Intent(appContext, MainActivity::class.java)
        return PendingIntent.getActivity(
            appContext,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        private const val CHANNEL_ID = "foreground_app_status"
        private const val NOTIFICATION_ID = 2001

        @Volatile private var instance: ForegroundAppNotificationController? = null

        fun getInstance(context: Context): ForegroundAppNotificationController {
            return instance ?: synchronized(this) {
                instance ?: ForegroundAppNotificationController(context.applicationContext).also { instance = it }
            }
        }
    }
}
