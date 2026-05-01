package com.minepacu.craftpresence.core.media

data class MediaTrack(
    val packageName: String = "",
    val title: String = "",
    val artist: String = "",
    val album: String = "",
    val durationMs: Long = 0L,
    val positionMs: Long = 0L,
    val artworkUri: String? = null,
    val isPlaying: Boolean = false,
)
