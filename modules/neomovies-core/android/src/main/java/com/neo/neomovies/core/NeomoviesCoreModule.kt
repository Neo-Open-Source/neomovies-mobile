package com.neo.neomovies.core

import android.media.MediaCodecList
import androidx.media3.common.util.UnstableApi
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import kotlin.math.roundToInt

@UnstableApi
class NeomoviesCoreModule : Module() {
  private fun toProgressPercent(positionMs: Long, durationMs: Long): Int {
    if (positionMs <= 0L || durationMs <= 0L) return 0
    return ((positionMs.toDouble() / durationMs.toDouble()) * 100.0)
      .roundToInt()
      .coerceIn(0, 100)
  }

  private fun buildWatchProgressPayload(
    kpId: Int,
    season: Int?,
    episode: Int?,
    positionMs: Long,
    durationMs: Long,
    watched: Boolean,
    updatedAtMs: Long,
  ): Map<String, Any?> {
    val mediaId = "kp_$kpId"
    return mapOf(
      "schemaVersion" to 1,
      "source" to "collaps",
      "mediaId" to mediaId,
      "kpId" to kpId,
      "season" to season,
      "episode" to episode,
      "kind" to if (season != null && episode != null) "episode" else "movie_or_generic",
      "positionMs" to positionMs,
      "durationMs" to durationMs,
      "progressPercent" to toProgressPercent(positionMs, durationMs),
      "watched" to watched,
      "updatedAtMs" to updatedAtMs,
    )
  }

  override fun definition() = ModuleDefinition {
    Name("NeomoviesCore")
    
    // Launch native ExoPlayer activity
    AsyncFunction("exoPlayerLaunch") { url: String, headers: Map<String, String>?, title: String? ->
      val activity = appContext.currentActivity ?: throw Exception("No current activity")
      val intent = android.content.Intent(activity, PlayerActivity::class.java).apply {
        putExtra(PlayerActivity.EXTRA_URL, url)
        putExtra(PlayerActivity.EXTRA_TITLE, title)
        putExtra(PlayerActivity.EXTRA_USE_EXO, true)
        putExtra(PlayerActivity.EXTRA_USE_COLLAPS_HEADERS, headers != null && headers.isNotEmpty())
        headers?.forEach { (key, value) ->
          putExtra("HEADER_$key", value)
        }
      }
      activity.startActivity(intent)
    }

    AsyncFunction("exoPlayerLaunchPlaylist") { urls: List<String>, startIndex: Int, headers: Map<String, String>?, names: List<String>?, title: String?, voiceNames: List<String>? ->
      val activity = appContext.currentActivity ?: throw Exception("No current activity")
      val intent = android.content.Intent(activity, PlayerActivity::class.java).apply {
        putStringArrayListExtra(PlayerActivity.EXTRA_URLS, ArrayList(urls))
        if (!names.isNullOrEmpty()) {
          putStringArrayListExtra(PlayerActivity.EXTRA_NAMES, ArrayList(names))
        }
        if (!voiceNames.isNullOrEmpty()) {
          putStringArrayListExtra(PlayerActivity.EXTRA_VOICE_NAMES, ArrayList(voiceNames))
        }
        putExtra(PlayerActivity.EXTRA_START_INDEX, startIndex)
        putExtra(PlayerActivity.EXTRA_TITLE, title)
        putExtra(PlayerActivity.EXTRA_USE_EXO, true)
        putExtra(PlayerActivity.EXTRA_USE_COLLAPS_HEADERS, headers != null && headers.isNotEmpty())
        headers?.forEach { (key, value) ->
          putExtra("HEADER_$key", value)
        }
      }
      activity.startActivity(intent)
    }
    
    // Export ExoPlayerView component
    View(ExoPlayerView::class) {
      Events("onReady", "onError", "onProgress", "onPlaybackStateChanged")
      
      Prop("source") { view: ExoPlayerView, url: String ->
        view.setSource(url)
      }
      
      Prop("paused") { view: ExoPlayerView, paused: Boolean ->
        if (paused) view.pause() else view.play()
      }
      
      Prop("playbackSpeed") { view: ExoPlayerView, speed: Float ->
        view.setPlaybackSpeed(speed)
      }
      
      AsyncFunction("seekTo") { view: ExoPlayerView, positionMs: Long ->
        view.seekTo(positionMs)
      }
    }

    Function("parseCollapsCatalog") { embedHtml: String ->
      CollapsParser.parseCollapsCatalog(embedHtml)
    }

    Function("rewriteCollapsHlsMaster") { master: String, voices: List<String>, subtitles: List<Map<String, String>>, mediaId: String ->
      val parsedSubtitles = subtitles.map {
        CollapsSubtitle(
          url = it["url"] ?: "",
          label = it["label"] ?: "",
          language = it["language"] ?: ""
        )
      }
      CollapsHlsRewriter.rewrite(master, voices, parsedSubtitles, mediaId)
    }

    Function("rewriteCollapsDashManifest") { manifest: String, voices: List<String>, subtitles: List<Map<String, String>>, mediaId: String ->
      val parsedSubtitles = subtitles.map {
        CollapsSubtitle(
          url = it["url"] ?: "",
          label = it["label"] ?: "",
          language = it["language"] ?: ""
        )
      }
      CollapsDashRewriter.rewrite(manifest, voices, parsedSubtitles, mediaId)
    }

    AsyncFunction("rewriteCollapsHlsFromUrl") { hlsUrl: String, voices: List<String>, subtitles: List<Map<String, String>>, mediaId: String, referer: String?, origin: String? ->
      val parsedSubtitles = subtitles.map {
        CollapsSubtitle(
          url = it["url"] ?: "",
          label = it["label"] ?: "",
          language = it["language"] ?: ""
        )
      }
      
      val masterPlaylist = kotlinx.coroutines.runBlocking {
        CollapsHTTPClient.fetch(hlsUrl, referer, origin)
      }
      CollapsHlsRewriter.rewrite(masterPlaylist, voices, parsedSubtitles, mediaId)
    }

    AsyncFunction("rewriteCollapsDashFromUrl") { dashUrl: String, voices: List<String>, subtitles: List<Map<String, String>>, mediaId: String, referer: String?, origin: String? ->
      val parsedSubtitles = subtitles.map {
        CollapsSubtitle(
          url = it["url"] ?: "",
          label = it["label"] ?: "",
          language = it["language"] ?: ""
        )
      }
      
      val manifest = kotlinx.coroutines.runBlocking {
        CollapsHTTPClient.fetch(dashUrl, referer, origin)
      }
      CollapsDashRewriter.rewrite(manifest, voices, parsedSubtitles, mediaId)
    }

    AsyncFunction("collapsDashContainsAv1") { dashUrl: String, referer: String?, origin: String? ->
      val manifest = kotlinx.coroutines.runBlocking {
        CollapsHTTPClient.fetch(dashUrl, referer, origin)
      }
      manifest.contains("av01", ignoreCase = true)
    }

    Function("collapsDeviceSupportsAv1") {
      val codecs = MediaCodecList(MediaCodecList.ALL_CODECS).codecInfos
      codecs.any { codecInfo ->
        !codecInfo.isEncoder && codecInfo.supportedTypes.any { type ->
          type.equals("video/av01", ignoreCase = true)
        }
      }
    }

    Function("getCollapsWatchProgress") { kpId: Int, season: Int?, episode: Int? ->
      val context = appContext.reactContext ?: throw Exception("No react context")
      val watchedPrefs = context.getSharedPreferences("collaps_watched", android.content.Context.MODE_PRIVATE)

      val lastSeason = watchedPrefs.getInt("kp_${kpId}_last_season", 0)
      val lastEpisode = watchedPrefs.getInt("kp_${kpId}_last_episode", 0)
      val lastPosition = watchedPrefs.getLong("kp_${kpId}_last_position", 0L)
      val lastDuration = watchedPrefs.getLong("kp_${kpId}_last_duration", 0L)
      val lastUpdatedAt = watchedPrefs.getLong("kp_${kpId}_last_updated_at", 0L)

      val resolvedSeason = season ?: if (lastSeason > 0) lastSeason else null
      val resolvedEpisode = episode ?: if (lastEpisode > 0) lastEpisode else null

      val episodeKey = if (resolvedSeason != null && resolvedEpisode != null) {
        "kp_${kpId}_s${resolvedSeason}_e${resolvedEpisode}"
      } else {
        null
      }

      val episodePosition = episodeKey?.let { watchedPrefs.getLong(it, 0L) } ?: 0L
      val episodeWatched = episodeKey?.let { watchedPrefs.getBoolean("${it}_watched", false) } ?: false
      val episodeDuration = episodeKey?.let { watchedPrefs.getLong("${it}_duration", 0L) } ?: 0L
      val episodeUpdatedAt = episodeKey?.let { watchedPrefs.getLong("${it}_updated_at", 0L) } ?: 0L

      val payload = buildWatchProgressPayload(
        kpId = kpId,
        season = resolvedSeason,
        episode = resolvedEpisode,
        positionMs = episodePosition,
        durationMs = episodeDuration,
        watched = episodeWatched,
        updatedAtMs = episodeUpdatedAt,
      )

      payload + mapOf(
        "lastSeason" to (if (lastSeason > 0) lastSeason else null),
        "lastEpisode" to (if (lastEpisode > 0) lastEpisode else null),
        "lastPositionMs" to lastPosition,
        "lastDurationMs" to lastDuration,
        "lastUpdatedAtMs" to lastUpdatedAt,
      )
    }

    Function("listCollapsWatchProgressRecords") { kpId: Int? ->
      val context = appContext.reactContext ?: throw Exception("No react context")
      val watchedPrefs = context.getSharedPreferences("collaps_watched", android.content.Context.MODE_PRIVATE)
      val entries = watchedPrefs.all
      val pattern = Regex("^kp_(\\d+)_s(\\d+)_e(\\d+)$")

      entries.keys
        .mapNotNull { key ->
          val match = pattern.matchEntire(key) ?: return@mapNotNull null
          val itemKpId = match.groupValues[1].toIntOrNull() ?: return@mapNotNull null
          if (kpId != null && itemKpId != kpId) return@mapNotNull null

          val season = match.groupValues[2].toIntOrNull() ?: return@mapNotNull null
          val episode = match.groupValues[3].toIntOrNull() ?: return@mapNotNull null
          val positionMs = watchedPrefs.getLong(key, 0L)
          val durationMs = watchedPrefs.getLong("${key}_duration", 0L)
          val watched = watchedPrefs.getBoolean("${key}_watched", false)
          val updatedAtMs = watchedPrefs.getLong("${key}_updated_at", 0L)

          buildWatchProgressPayload(
            kpId = itemKpId,
            season = season,
            episode = episode,
            positionMs = positionMs,
            durationMs = durationMs,
            watched = watched,
            updatedAtMs = updatedAtMs,
          )
        }
        .sortedByDescending { (it["updatedAtMs"] as? Long) ?: 0L }
    }
  }
}
