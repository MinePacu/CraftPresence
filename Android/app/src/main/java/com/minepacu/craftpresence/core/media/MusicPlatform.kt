package com.minepacu.craftpresence.core.media

enum class MusicPlatform(
    val displayName: String,
    val packageName: String,
) {
    YOUTUBE_MUSIC("YouTube Music", "com.google.android.apps.youtube.music"),
    SPOTIFY("Spotify", "com.spotify.music"),
    APPLE_MUSIC("Apple Music", "com.apple.android.music");

    companion object {
        fun fromPackageName(packageName: String?): MusicPlatform? {
            return entries.firstOrNull { it.packageName == packageName }
        }
    }
}
