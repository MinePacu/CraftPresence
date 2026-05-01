package com.minepacu.craftpresence.core.presence

import android.content.Context
import com.minepacu.craftpresence.core.discord.DiscordActivity
import com.minepacu.craftpresence.core.discord.DiscordSdkManager
import com.minepacu.craftpresence.core.media.ArtworkLookup
import com.minepacu.craftpresence.core.media.MediaSessionNowPlayingMonitor
import com.minepacu.craftpresence.core.media.MediaTrack
import com.minepacu.craftpresence.core.media.MusicPlatform
import com.minepacu.craftpresence.core.util.LruMemoryCache
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class AppleMusicPresenceState(
    val enabledPlatforms: Set<MusicPlatform> = emptySet(),
    val activePlatform: MusicPlatform? = null,
    val currentTrack: String = "",
    val currentArtist: String = "",
    val currentAlbum: String = "",
    val isPlaying: Boolean = false,
    val discordStatus: String = "Not Connected",
    val albumArtworkUrl: String? = null,
) {
    val isEnabled: Boolean get() = enabledPlatforms.isNotEmpty()

    fun isPlatformEnabled(platform: MusicPlatform): Boolean = platform in enabledPlatforms
}

class AppleMusicPresenceManager private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val monitor = MediaSessionNowPlayingMonitor(appContext)
    private val discord = DiscordSdkManager.getInstance(appContext)
    private val artworkLookup = ArtworkLookup()
    private val artworkUrlCache = LruMemoryCache<String, String>(capacity = 80)
    private val missingArtworkCache = LruMemoryCache<String, Boolean>(capacity = 80)

    private var monitorJob: Job? = null
    private var updateJob: Job? = null
    private var lastUpdateTimeMs: Long = 0L
    private var isDiscordConfigured = false
    private var lastTrackKey = ""
    private var latestTrack = MediaTrack()

    private val _state = MutableStateFlow(AppleMusicPresenceState())
    val state: StateFlow<AppleMusicPresenceState> = _state.asStateFlow()

    fun startMonitoring(platform: MusicPlatform? = null) {
        val nextPlatforms = if (platform == null) {
            MusicPlatform.entries.toSet()
        } else {
            _state.value.enabledPlatforms + platform
        }
        if (nextPlatforms == _state.value.enabledPlatforms && monitorJob != null) return

        _state.value = _state.value.copy(enabledPlatforms = nextPlatforms, discordStatus = "Configuring...")
        if (monitorJob == null) {
            monitor.start(nextPlatforms.map { it.packageName }.toSet())
        } else {
            monitor.updateAllowedPackages(nextPlatforms.map { it.packageName }.toSet())
        }

        if (monitorJob != null) return

        monitorJob = scope.launch {
            ensureDiscordConfigured()
            monitor.currentTrack.collect { track ->
                latestTrack = track
                handleTrackUpdate(track)
            }
        }

        updateJob = scope.launch {
            while (true) {
                delay(MINIMUM_UPDATE_INTERVAL_MS)
                updateDiscordIfNeeded()
            }
        }
    }

    fun stopMonitoring(platform: MusicPlatform? = null) {
        val nextPlatforms = if (platform == null) {
            emptySet()
        } else {
            _state.value.enabledPlatforms - platform
        }
        if (nextPlatforms.isNotEmpty()) {
            _state.value = _state.value.copy(enabledPlatforms = nextPlatforms)
            monitor.updateAllowedPackages(nextPlatforms.map { it.packageName }.toSet())
            if (_state.value.activePlatform == platform) {
                latestTrack = MediaTrack()
                scope.launch { discord.clearActivity() }
                _state.value = _state.value.copy(
                    activePlatform = null,
                    currentTrack = "",
                    currentArtist = "",
                    currentAlbum = "",
                    isPlaying = false,
                    discordStatus = "Idle",
                    albumArtworkUrl = null,
                )
            }
            return
        }

        monitorJob?.cancel()
        updateJob?.cancel()
        monitorJob = null
        updateJob = null
        monitor.stop()
        scope.launch { discord.clearActivity() }
        _state.value = AppleMusicPresenceState(discordStatus = "Not Connected")
    }

    private suspend fun ensureDiscordConfigured() {
        if (isDiscordConfigured) return
        discord.configure(autoAuthorize = false)
        isDiscordConfigured = true
        _state.value = _state.value.copy(discordStatus = "Configured")
    }

    private suspend fun handleTrackUpdate(track: MediaTrack) {
        val platform = MusicPlatform.fromPackageName(track.packageName)
        if (!track.isPlaying) {
            if (_state.value.isPlaying) discord.clearActivity()
            _state.value = _state.value.copy(
                activePlatform = null,
                currentTrack = "",
                currentArtist = "",
                currentAlbum = "",
                isPlaying = false,
                discordStatus = "Idle",
                albumArtworkUrl = null,
            )
            return
        }

        if (platform == null || platform !in _state.value.enabledPlatforms) return

        val cacheKey = normalizedCacheKey(track.artist, track.album, track.title)
        val trackChanged = cacheKey != lastTrackKey
        lastTrackKey = cacheKey
        val artworkUrl = track.artworkUri ?: artworkUrlCache.get(cacheKey)
        _state.value = _state.value.copy(
            currentTrack = track.title,
            currentArtist = track.artist,
            currentAlbum = track.album,
            activePlatform = platform,
            isPlaying = true,
            albumArtworkUrl = artworkUrl,
        )

        if (artworkUrl == null && trackChanged && missingArtworkCache.get(cacheKey) != true) {
            val fetchedArtworkUrl = artworkLookup.fetchArtworkUrl(track.artist, track.album, track.title)
            if (fetchedArtworkUrl.isNullOrBlank()) {
                missingArtworkCache.put(cacheKey, true)
            } else {
                artworkUrlCache.put(cacheKey, fetchedArtworkUrl)
                _state.value = _state.value.copy(albumArtworkUrl = fetchedArtworkUrl)
            }
        }

        if (trackChanged) updateDiscordPresence()
    }

    private suspend fun updateDiscordIfNeeded() {
        if (!latestTrack.isPlaying) return
        if (System.currentTimeMillis() - lastUpdateTimeMs < MINIMUM_UPDATE_INTERVAL_MS) return
        updateDiscordPresence()
    }

    private suspend fun updateDiscordPresence() {
        val track = latestTrack
        if (!track.isPlaying || !isDiscordConfigured) return

        val nowSeconds = System.currentTimeMillis() / 1000L
        val start = nowSeconds - (track.positionMs / 1000L)
        val end = if (track.durationMs > 0L) nowSeconds + ((track.durationMs - track.positionMs) / 1000L) else null

        runCatching {
            discord.updateActivity(
                DiscordActivity(
                    name = MusicPlatform.fromPackageName(track.packageName)?.displayName ?: "Music",
                    state = track.artist.ifBlank { "Unknown Artist" },
                    details = track.title.ifBlank { "Unknown Track" },
                    largeImageKey = _state.value.albumArtworkUrl.orEmpty(),
                    startEpochSeconds = start,
                    endEpochSeconds = end,
                    activityType = DiscordActivity.ActivityType.LISTENING,
                ),
            )
        }.onSuccess {
            lastUpdateTimeMs = System.currentTimeMillis()
            _state.value = _state.value.copy(discordStatus = "Active")
        }.onFailure {
            _state.value = _state.value.copy(discordStatus = "Update Failed")
        }
    }

    private fun normalizedCacheKey(artist: String, album: String, track: String): String {
        return listOf(artist, album, track)
            .joinToString("|") { it.trim().lowercase() }
    }

    companion object {
        private const val MINIMUM_UPDATE_INTERVAL_MS = 15_000L

        @Volatile private var instance: AppleMusicPresenceManager? = null

        fun getInstance(context: Context): AppleMusicPresenceManager {
            return instance ?: synchronized(this) {
                instance ?: AppleMusicPresenceManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
