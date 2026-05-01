package com.minepacu.craftpresence.core.media

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URLEncoder
import java.net.URL

class ArtworkLookup {
    suspend fun fetchArtworkUrl(artist: String, album: String, track: String): String? {
        val songQuery = listOf(artist, album, track).joinToString(" ").trim()
        return searchArtworkUrl(songQuery, "song") ?: searchArtworkUrl(
            listOf(artist, album).joinToString(" ").trim(),
            "album",
        )
    }

    private suspend fun searchArtworkUrl(query: String, entity: String): String? = withContext(Dispatchers.IO) {
        if (query.isBlank()) return@withContext null
        val encoded = URLEncoder.encode(query, Charsets.UTF_8.name())
        val url = URL("https://itunes.apple.com/search?term=$encoded&media=music&entity=$entity&limit=1")
        val connection = (url.openConnection() as HttpURLConnection).apply {
            connectTimeout = 5_000
            readTimeout = 8_000
            requestMethod = "GET"
            setRequestProperty("Accept", "application/json")
        }

        try {
            if (connection.responseCode !in 200..299) return@withContext null
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val results = JSONObject(body).optJSONArray("results") ?: return@withContext null
            val artworkUrl = results.optJSONObject(0)?.optString("artworkUrl100").orEmpty()
            artworkUrl.takeIf { it.isNotBlank() }?.replace("100x100", "600x600")
        } catch (_: Exception) {
            null
        } finally {
            connection.disconnect()
        }
    }
}
