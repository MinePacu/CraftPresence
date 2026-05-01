package com.minepacu.craftpresence.core.media

import android.content.ComponentName
import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class MediaSessionNowPlayingMonitor(context: Context) {
    private val appContext = context.applicationContext
    private val mediaSessionManager = appContext.getSystemService(MediaSessionManager::class.java)
    private val notificationListener = ComponentName(appContext, NowPlayingNotificationListener::class.java)

    private var activeController: MediaController? = null
    private var allowedPackages: Set<String> = emptySet()
    private val callback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) {
            publish(activeController)
        }

        override fun onPlaybackStateChanged(state: PlaybackState?) {
            publish(activeController)
        }
    }

    private val sessionsChangedListener = MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
        bindController(controllers?.firstSupportedPlayingController())
    }

    private val _currentTrack = MutableStateFlow(MediaTrack())
    val currentTrack: StateFlow<MediaTrack> = _currentTrack.asStateFlow()

    fun start(allowedPackages: Set<String>) {
        this.allowedPackages = allowedPackages
        val controllers = runCatching {
            mediaSessionManager.getActiveSessions(notificationListener)
        }.getOrDefault(emptyList())
        bindController(controllers.firstSupportedPlayingController())
        runCatching {
            mediaSessionManager.addOnActiveSessionsChangedListener(sessionsChangedListener, notificationListener)
        }
    }

    fun updateAllowedPackages(allowedPackages: Set<String>) {
        this.allowedPackages = allowedPackages
        val controllers = runCatching {
            mediaSessionManager.getActiveSessions(notificationListener)
        }.getOrDefault(emptyList())
        bindController(controllers.firstSupportedPlayingController())
    }

    fun stop() {
        activeController?.unregisterCallback(callback)
        activeController = null
        runCatching { mediaSessionManager.removeOnActiveSessionsChangedListener(sessionsChangedListener) }
        _currentTrack.value = MediaTrack()
    }

    private fun bindController(controller: MediaController?) {
        if (activeController == controller) {
            publish(controller)
            return
        }
        activeController?.unregisterCallback(callback)
        activeController = controller
        controller?.registerCallback(callback)
        publish(controller)
    }

    private fun publish(controller: MediaController?) {
        val metadata = controller?.metadata
        val state = controller?.playbackState
        val isPlaying = state?.state == PlaybackState.STATE_PLAYING
        val packageName = controller?.packageName.orEmpty()

        _currentTrack.value = if (metadata == null || !isPlaying || !isAllowed(packageName)) {
            MediaTrack()
        } else {
            MediaTrack(
                packageName = packageName,
                title = metadata.getString(MediaMetadata.METADATA_KEY_TITLE).orEmpty(),
                artist = metadata.getString(MediaMetadata.METADATA_KEY_ARTIST).orEmpty(),
                album = metadata.getString(MediaMetadata.METADATA_KEY_ALBUM).orEmpty(),
                durationMs = metadata.getLong(MediaMetadata.METADATA_KEY_DURATION).coerceAtLeast(0L),
                positionMs = state.position.coerceAtLeast(0L),
                artworkUri = metadata.getString(MediaMetadata.METADATA_KEY_ART_URI)
                    ?: metadata.getString(MediaMetadata.METADATA_KEY_ALBUM_ART_URI),
                isPlaying = true,
            )
        }
    }

    private fun List<MediaController>.firstSupportedPlayingController(): MediaController? {
        return firstOrNull { controller ->
            controller.playbackState?.state == PlaybackState.STATE_PLAYING &&
                isAllowed(controller.packageName)
        }
    }

    private fun isAllowed(packageName: String): Boolean {
        return allowedPackages.isEmpty() || packageName in allowedPackages
    }
}
