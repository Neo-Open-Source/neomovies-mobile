package com.neo.neomovies.core

import android.app.Application
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackGroup
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.database.DatabaseProvider
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.RenderersFactory
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.mediacodec.MediaCodecUtil
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.extractor.DefaultExtractorsFactory
import androidx.media3.extractor.ts.DefaultTsPayloadReaderFactory
import androidx.media3.extractor.ts.TsExtractor
import java.io.File
import java.net.URLDecoder
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update

class PlayerViewModel(
    application: Application,
    private val savedStateHandle: SavedStateHandle,
) : AndroidViewModel(application), Player.Listener {

    private data class LastInitArgs(
        val urls: List<String>,
        val names: List<String>?,
        val voiceNames: List<String>?,
        val title: String?,
        val kinopoiskId: Int?,
    )

    var player: Player
        private set

    private var useExo: Boolean = false
    var playbackSpeed: Float = 1f
    var isInPictureInPictureMode: Boolean = false
    var playWhenReady: Boolean = true
    private var baseTitle: String = ""

    private var kpId: Int? = null
    private var onEpisodeProgressUpdate: ((Int, Int, Int, Long, Long) -> Unit)? = null

    fun setKinopoiskId(id: Int) {
        kpId = id
    }
    private var pendingStartPositionMs: Long? = null
    private var pendingProgressKey: String? = null
    private var episodeVoiceNames: List<String> = emptyList()
    private var lastInitArgs: LastInitArgs? = null
    private var preferSoftwareDecoder: Boolean = false
    private val forceAv1SoftwareDecoder: Boolean = false

    private val useCollapsHeaders: Boolean by lazy {
        savedStateHandle.get<Boolean>(PlayerActivity.EXTRA_USE_COLLAPS_HEADERS) ?: false
    }

    private val forceFirstAudioTrack: Boolean by lazy { useCollapsHeaders }
    private var appliedFirstAudioOverride: Boolean = false
    private var preferredAudioLabel: String? = null
    private var preferredVideoHeight: Int? = null
    private var prefersAutoVideoQuality: Boolean = true
    
    private val collapsHeaders: Map<String, String> by lazy {
        val prefixed = runCatching {
            savedStateHandle.keys()
                .filter { it.startsWith("HEADER_") }
                .associateWith { key -> savedStateHandle.get<String>(key).orEmpty() }
                .mapKeys { (key, _) -> key.removePrefix("HEADER_") }
                .filterValues { it.isNotBlank() }
        }.getOrDefault(emptyMap())
        
        if (prefixed.isNotEmpty()) {
            prefixed
        } else {
            mapOf(
                "Referer" to "https://kinokrad.my/",
                "Origin" to "https://kinokrad.my",
            )
        }
    }

    private val _uiState = MutableStateFlow(UiState(currentItemTitle = "", fileLoaded = false))
    val uiState = _uiState.asStateFlow()

    private val _tracksVersion = MutableStateFlow(0)
    val tracksVersion = _tracksVersion.asStateFlow()

    private val _playerEpoch = MutableStateFlow(0)
    val playerEpoch = _playerEpoch.asStateFlow()

    private val eventsChannel = Channel<PlayerEvents>(capacity = Channel.BUFFERED)
    val eventsChannelFlow = eventsChannel.receiveAsFlow()

    data class UiState(
        val currentItemTitle: String,
        val fileLoaded: Boolean,
    )

    private val prefs by lazy {
        application.getSharedPreferences("player_progress", Context.MODE_PRIVATE)
    }

    private val watchedPrefs by lazy {
        application.getSharedPreferences("collaps_watched", Context.MODE_PRIVATE)
    }

    // Shared AudioAttributes to avoid duplication
    private val audioAttributes = AudioAttributes.Builder()
        .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
        .setUsage(C.USAGE_MEDIA)
        .build()

    init {
        useExo = savedStateHandle.get<Boolean>(PlayerActivity.EXTRA_USE_EXO) ?: true
        
        Log.d("PlayerVM", "init useExo=$useExo")
        player = createPlayer(useExo, preferSoftwareDecoder)
        player.addListener(this)
    }

    fun setEngine(useExo: Boolean) {
        if (this.useExo == useExo) return
        this.useExo = useExo

        player.removeListener(this)
        player.release()

        player = createPlayer(useExo, preferSoftwareDecoder)
        player.addListener(this)
        _playerEpoch.update { it + 1 }
        
        // Note: You might need to re-initialize the playlist here 
        // if engine is switched during playback.
    }

    private fun createPlayer(useExo: Boolean, preferSoftwareDecoder: Boolean): Player {
        val trackSelector = DefaultTrackSelector(getApplication()).apply {
            parameters = buildUponParameters()
                .setAllowInvalidateSelectionsOnRendererCapabilitiesChange(true)
                .build()
        }

        val extractorsFactory = DefaultExtractorsFactory()
            .setTsExtractorFlags(DefaultTsPayloadReaderFactory.FLAG_ENABLE_HDMV_DTS_AUDIO_STREAMS)
            .setTsExtractorTimestampSearchBytes(1500 * TsExtractor.TS_PACKET_SIZE)

        val httpDataSourceFactory = DefaultHttpDataSource.Factory()
        if (useCollapsHeaders) {
            httpDataSourceFactory.setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
            val requestHeaders = mapOf(
                "Referer" to "https://kinokrad.my/",
                "Origin" to "https://kinokrad.my",
            ) + collapsHeaders
            Log.d("PlayerVM", "Using Collaps headers: $requestHeaders")
            httpDataSourceFactory.setDefaultRequestProperties(requestHeaders)
        }

        val upstreamFactory = LoggingDataSourceFactory(
            delegate = DefaultDataSource.Factory(getApplication(), httpDataSourceFactory),
            headers = if (useCollapsHeaders) {
                mapOf(
                    "Referer" to "https://kinokrad.my/",
                    "Origin" to "https://kinokrad.my",
                    "User-Agent" to "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
                ) + collapsHeaders
            } else {
                emptyMap()
            }
        )
        val dataSourceFactory = CacheDataSource.Factory()
            .setCache(PlayerCacheStore.getDownloadCache(getApplication()))
            .setUpstreamDataSourceFactory(upstreamFactory)
            .setCacheWriteDataSinkFactory(null)
        val mediaSourceFactory = DefaultMediaSourceFactory(dataSourceFactory, extractorsFactory)

        val extensionMode = if (isEmulator()) {
            DefaultRenderersFactory.EXTENSION_RENDERER_MODE_OFF
        } else if (preferSoftwareDecoder) {
            DefaultRenderersFactory.EXTENSION_RENDERER_MODE_PREFER
        } else {
            DefaultRenderersFactory.EXTENSION_RENDERER_MODE_ON
        }

        val av1PreferringSelector = MediaCodecSelector { mimeType, requiresSecureDecoder, requiresTunnelingDecoder ->
            if ((preferSoftwareDecoder || forceAv1SoftwareDecoder) && mimeType.equals(MimeTypes.VIDEO_AV1, ignoreCase = true)) {
                Log.w("PlayerVM", "MediaCodecSelector: blocking MediaCodec for AV1 mime=$mimeType")
                emptyList()
            } else {
                MediaCodecUtil.getDecoderInfos(mimeType, requiresSecureDecoder, requiresTunnelingDecoder)
            }
        }

        val renderersFactory = DefaultRenderersFactory(getApplication())
            .setExtensionRendererMode(extensionMode)
            .setEnableDecoderFallback(true)
            .setMediaCodecSelector(av1PreferringSelector)

        return ExoPlayer.Builder(getApplication(), renderersFactory)
            .setTrackSelector(trackSelector)
            .setMediaSourceFactory(mediaSourceFactory)
            .build().apply {
                setAudioAttributes(this@PlayerViewModel.audioAttributes, true)
                setPauseAtEndOfMediaItems(false)
                addAnalyticsListener(createAnalyticsListener())
            }
    }

    private fun isEmulator(): Boolean {
        return Build.FINGERPRINT.contains("generic") ||
                Build.MODEL.contains("emulator") ||
                Build.MODEL.contains("sdk_gphone") ||
                Build.MANUFACTURER.contains("genymotion")
    }

    private fun createAnalyticsListener() = object : AnalyticsListener {
        override fun onVideoDecoderInitialized(eventTime: AnalyticsListener.EventTime, decoderName: String, initializedTimestampMs: Long, initializationDurationMs: Long) {
            Log.d("PlayerVM", "VideoDecoder: $decoderName")
        }
        override fun onPlayerError(eventTime: AnalyticsListener.EventTime, error: PlaybackException) {
            Log.e("PlayerVM", "Error: ${error.errorCodeName}", error)
        }
    }

    fun initializePlayer(
        urls: List<String>,
        names: List<String>?,
        voiceNames: List<String>? = null,
        startIndex: Int,
        title: String?,
        startFromBeginning: Boolean,
        kinopoiskId: Int? = null,
        episodeProgressCallback: ((Int, Int, Int, Long, Long) -> Unit)? = null,
    ) {
        Log.d("PlayerVM", "initializePlayer: urls=$urls, startIndex=$startIndex, title=$title")
        
        baseTitle = title?.takeIf { it.isNotBlank() } ?: ""
        episodeVoiceNames = voiceNames.orEmpty()
        kpId = kinopoiskId
        lastInitArgs = LastInitArgs(
            urls = urls,
            names = names,
            voiceNames = voiceNames,
            title = title,
            kinopoiskId = kinopoiskId,
        )
        onEpisodeProgressUpdate = episodeProgressCallback
        _uiState.update { it.copy(currentItemTitle = baseTitle, fileLoaded = false) }
        appliedFirstAudioOverride = false

        val resolvedUrls = urls

        val mediaItems = resolvedUrls.mapIndexed { index, url ->
            val displayName = names?.getOrNull(index).orEmpty()
            val extras = Bundle().apply { putString("display_name", displayName) }
            MediaItem.Builder()
                .setMediaId(url)
                .setUri(url)
                .setMediaMetadata(
                    MediaMetadata.Builder()
                        .setTitle(baseTitle)
                        .setExtras(extras)
                        .build()
                )
                .build()
        }

        val currentUrl = resolvedUrls.getOrNull(startIndex) ?: resolvedUrls.firstOrNull().orEmpty()
        val initialItem = mediaItems.getOrNull(startIndex)
        if (initialItem != null) {
            _uiState.update { it.copy(currentItemTitle = buildDisplayTitle(initialItem)) }
        }

        val progressKey = "pos_$currentUrl"
        val startPosition = if (startFromBeginning) 0L else prefs.getLong(progressKey, 0L)
        pendingStartPositionMs = if (startPosition > 0L) startPosition else null
        pendingProgressKey = progressKey
        Log.d("PlayerVM", "Restored progress: key=$progressKey position=$startPosition")

        Log.d("PlayerVM", "Setting media items: count=${mediaItems.size}, startIndex=$startIndex, startPosition=$startPosition")
        player.setMediaItems(mediaItems, startIndex, startPosition)
        player.prepare()
        player.playWhenReady = true
        Log.d("PlayerVM", "Player prepared and playWhenReady set to true")
    }


    override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
        _uiState.update { it.copy(currentItemTitle = buildDisplayTitle(mediaItem)) }
        appliedFirstAudioOverride = false
    }

    override fun onTracksChanged(tracks: Tracks) {
        _tracksVersion.update { it + 1 }
        if (!useExo) return

        logVideoTracks(tracks)

        val appliedPreferredAudio = applyPreferredAudioTrackIfAny()
        val appliedPreferredVideo = applyPreferredVideoQualityIfAny()
        if (appliedPreferredAudio || appliedPreferredVideo) {
            return
        }

        if (!forceFirstAudioTrack || appliedFirstAudioOverride || preferredAudioLabel != null) return

        val audioGroups = tracks.groups.filter { it.type == C.TRACK_TYPE_AUDIO }
        val group = audioGroups.firstOrNull() ?: return
        val trackGroup = group.mediaTrackGroup
        if (trackGroup.length > 0) {
            player.trackSelectionParameters = player.trackSelectionParameters
                .buildUpon()
                .clearOverridesOfType(C.TRACK_TYPE_AUDIO)
                .setOverrideForType(TrackSelectionOverride(trackGroup, listOf(0)))
                .setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, false)
                .build()
            appliedFirstAudioOverride = true
        }
    }

    private fun logVideoTracks(tracks: Tracks) {
        val videoGroups = tracks.groups.filter { it.type == C.TRACK_TYPE_VIDEO }
        if (videoGroups.isEmpty()) {
            Log.w("PlayerVM", "videoTrack: no video groups exposed")
            return
        }
        for (group in videoGroups) {
            val trackGroup = group.mediaTrackGroup
            for (i in 0 until trackGroup.length) {
                val format = trackGroup.getFormat(i)
                Log.d(
                    "PlayerVM",
                    "videoTrack: id=${format.id} mime=${format.sampleMimeType} codecs=${format.codecs} ${format.width}x${format.height} supported=${group.isTrackSupported(i)} selected=${group.isTrackSelected(i)}"
                )
            }
        }
    }

    private fun applyPreferredAudioTrackIfAny(): Boolean {
        val preferredLabel = preferredAudioLabel?.trim()?.takeIf { it.isNotEmpty() } ?: return false
        val audioTracks = getSelectableTracks(C.TRACK_TYPE_AUDIO)
        if (audioTracks.isEmpty()) return false

        val targetIndex = audioTracks.indexOfFirst { track ->
            track.isSupported && track.label.equals(preferredLabel, ignoreCase = true)
        }
        if (targetIndex < 0) return false

        switchToTrack(C.TRACK_TYPE_AUDIO, targetIndex)
        return true
    }

    private fun applyPreferredVideoQualityIfAny(): Boolean {
        if (prefersAutoVideoQuality) return false

        val preferredHeight = preferredVideoHeight ?: return false
        val videoTracks = getSelectableTracks(C.TRACK_TYPE_VIDEO)
        if (videoTracks.isEmpty()) return false

        val targetIndex = videoTracks.indexOfFirst { track ->
            track.isSupported && track.height == preferredHeight
        }
        if (targetIndex < 0) return false

        switchToTrack(C.TRACK_TYPE_VIDEO, targetIndex)
        return true
    }

    private fun buildDisplayTitle(mediaItem: MediaItem?): String {
        val displayName = mediaItem?.mediaMetadata?.extras?.getString("display_name").orEmpty()
        val rawName = displayName.ifBlank {
            val url = mediaItem?.localConfiguration?.uri?.toString().orEmpty()
            url.substringAfterLast('/').substringAfterLast('\\')
        }
        val fileName = runCatching { URLDecoder.decode(rawName, "UTF-8") }.getOrDefault(rawName)
        val se = parseSeasonEpisode(fileName)

        return when {
            se != null && baseTitle.isNotBlank() -> "$baseTitle • $se"
            baseTitle.isNotBlank() -> baseTitle
            else -> fileName
        }
    }

    private fun parseSeasonEpisode(name: String): String? {
        val patterns = listOf(
            "(?i)S(\\d{1,2})\\s*[._-]?\\s*E(\\d{1,3})",
            "(?i)\\b(\\d{1,2})\\s*[xX]\\s*(\\d{1,3})\\b",
            "(?i)season\\s*(\\d{1,2}).*episode\\s*(\\d{1,3})",
            "(?i)kp_\\d+_(\\d{1,2})_(\\d{1,3})"
        )
        
        for (pattern in patterns) {
            Regex(pattern).find(name)?.let { m ->
                val s = m.groupValues[1].toIntOrNull()
                val e = m.groupValues[2].toIntOrNull()
                if (s != null && e != null) {
                    return if (pattern.contains("x")) "%dx%02d".format(s, e) else "S%02dE%02d".format(s, e)
                }
            }
        }
        return null
    }

    // For Alloha the proxy URL is always the same — use kpId+episodeIndex as unique key
    private fun progressKey(): String {
        val mediaId = player.currentMediaItem?.mediaId ?: return ""
        return "pos_$mediaId"
    }

    fun clearCurrentProgress() {
        val key = progressKey().takeIf { it.isNotBlank() } ?: return
        prefs.edit().remove(key).apply()
    }

    fun clearEpisodeProgress(episodeIndex: Int) {
        if (kpId == null) return
        prefs.edit().remove("pos_alloha_${kpId}_ep$episodeIndex").apply()
    }

    fun updatePlaybackProgress() {
        val key = progressKey().takeIf { it.isNotBlank() } ?: return
        val position = player.currentPosition
        val now = System.currentTimeMillis()
        prefs.edit().putLong(key, position).apply()
        savedStateHandle["position"] = position
        
        // Update Collaps episode progress if available
        val displayName = player.currentMediaItem?.mediaMetadata?.extras?.getString("display_name").orEmpty()
        val displayTitle = buildDisplayTitle(player.currentMediaItem)
        val se = parseSeasonEpisode(displayName)
            ?: parseSeasonEpisode(displayTitle)
            ?: run {
                val url = player.currentMediaItem?.localConfiguration?.uri?.toString().orEmpty()
                parseSeasonEpisode(url.substringAfterLast('/').substringAfterLast('\\'))
            }
        val currentKpId = kpId
        val duration = player.duration
        if (se != null && baseTitle.isNotBlank()) {
            // Extract season and episode from SxxEyy format
            val match = Regex("S(\\d{1,2})E(\\d{1,3})").find(se)
            if (match != null) {
                val season = match.groupValues[1].toIntOrNull()
                val episode = match.groupValues[2].toIntOrNull()
                if (currentKpId != null && season != null && episode != null) {
                    val cb = onEpisodeProgressUpdate
                    if (cb != null) {
                        cb(currentKpId, season, episode, position, duration)
                        return
                    }
                    persistEpisodeProgress(currentKpId, season, episode, position, duration)
                    return
                }
            }
        }

        val cb = onEpisodeProgressUpdate
        if (currentKpId != null && cb != null) {
            cb(currentKpId, 0, 0, position, duration)
            return
        }

        // Persist generic (movie/non-episodic) progress by Kinopoisk ID so DetailsScreen can show resume.
        if (currentKpId != null) {
            watchedPrefs.edit()
                .putLong("kp_${currentKpId}_last_position", position)
                .putLong("kp_${currentKpId}_last_duration", duration)
                .putLong("kp_${currentKpId}_last_updated_at", now)
                .apply()
        }
    }

    private fun persistEpisodeProgress(kpId: Int, season: Int, episode: Int, positionMs: Long, durationMs: Long) {
        if (season <= 0 || episode <= 0) return
        val watchedKey = "kp_${kpId}_s${season}_e${episode}"
        val now = System.currentTimeMillis()
        val watchedThresholdMs = if (durationMs > 0) {
            val percentThreshold = (durationMs * 0.85f).toLong()
            val creditsThreshold = durationMs - 180_000L
            maxOf(percentThreshold, creditsThreshold)
        } else {
            Long.MAX_VALUE
        }
        val watched = durationMs > 0 && positionMs >= watchedThresholdMs
        watchedPrefs.edit()
            .putLong(watchedKey, positionMs)
            .putBoolean("${watchedKey}_watched", watched)
            .putLong("${watchedKey}_duration", durationMs)
            .putLong("${watchedKey}_updated_at", now)
            .putInt("kp_${kpId}_last_season", season)
            .putInt("kp_${kpId}_last_episode", episode)
            .putLong("kp_${kpId}_last_position", positionMs)
            .putLong("kp_${kpId}_last_duration", durationMs)
            .putLong("kp_${kpId}_last_updated_at", now)
            .apply()
    }

    fun getSelectableTracks(trackType: @C.TrackType Int): List<SelectableTrack> {
        val groups = player.currentTracks.groups.filter { it.type == trackType }
        val result = ArrayList<SelectableTrack>()
        var displayIndex = 1
        val dedupeKeys = HashSet<String>()

        for (group in groups) {
            val trackGroup = group.mediaTrackGroup
            for (i in 0 until trackGroup.length) {
                val format = trackGroup.getFormat(i)
                val label = format.label
                val language = format.language
                
                val displayLabel = when {
                    trackType == C.TRACK_TYPE_VIDEO && format.height > 0 -> "${format.height}p"
                    trackType == C.TRACK_TYPE_AUDIO -> resolveAudioLabel(format.id, label)
                    !label.isNullOrBlank() -> label
                    !language.isNullOrBlank() && language != "und" -> language
                    else -> "Track ${displayIndex++}"
                }

                val dedupeKey = when (trackType) {
                    C.TRACK_TYPE_VIDEO -> "video:${format.height}:${displayLabel}"
                    C.TRACK_TYPE_AUDIO -> "audio:${displayLabel}:${language ?: ""}"
                    else -> "$trackType:${format.id}:${displayLabel}"
                }
                if (!dedupeKeys.add(dedupeKey)) continue

                if (trackType == C.TRACK_TYPE_AUDIO) {
                    Log.d(
                        "PlayerVM",
                        "audioTrack: id=${format.id} lang=${format.language} label=${format.label} display=$displayLabel supported=${group.isTrackSupported(i)} selected=${group.isTrackSelected(i)}"
                    )
                }

                result += SelectableTrack(
                    label = displayLabel,
                    formatId = format.id,
                    trackGroup = trackGroup,
                    trackIndex = i,
                    isSelected = group.isTrackSelected(i),
                    isSupported = group.isTrackSupported(i),
                    height = format.height
                )
            }
        }

        if (trackType == C.TRACK_TYPE_VIDEO) {
            result.sortByDescending { it.height }
        }
        return result
    }

    private fun resolveAudioLabel(formatId: String?, fallbackLabel: String?): String {
        val raw = fallbackLabel?.trim().orEmpty()
        val idx = extractAudioIndex(formatId) ?: extractAudioIndex(raw)
        val voice = idx?.let { episodeVoiceNames.getOrNull(it) }?.trim().orEmpty()
        if (voice.isNotEmpty()) return voice
        return raw.ifEmpty { "Audio" }
    }

    private fun extractAudioIndex(raw: String?): Int? {
        if (raw.isNullOrBlank()) return null
        val m = Regex("(?:^|[^a-z0-9])(?:rus|ru|eng|en|ukr|ua)(\\d+)(?:$|[^a-z0-9])", RegexOption.IGNORE_CASE)
            .find(raw)
        return m?.groupValues?.getOrNull(1)?.toIntOrNull()
    }

    fun switchToTrack(trackType: @C.TrackType Int, index: Int) {
        when (trackType) {
            C.TRACK_TYPE_AUDIO -> {
                if (index >= 0) {
                    val selected = getSelectableTracks(C.TRACK_TYPE_AUDIO).getOrNull(index)
                    preferredAudioLabel = selected?.label
                }
            }
            C.TRACK_TYPE_VIDEO -> {
                if (index == -1) {
                    prefersAutoVideoQuality = true
                    preferredVideoHeight = null
                } else {
                    val selected = getSelectableTracks(C.TRACK_TYPE_VIDEO).getOrNull(index)
                    prefersAutoVideoQuality = false
                    preferredVideoHeight = selected?.height?.takeIf { it > 0 }
                }
            }
        }

        val builder = player.trackSelectionParameters.buildUpon()
        if (index == -1) {
            builder.clearOverridesOfType(trackType)
                   .setTrackTypeDisabled(trackType, trackType == C.TRACK_TYPE_TEXT)
        } else {
            val track = getSelectableTracks(trackType).getOrNull(index) ?: return
            builder.clearOverridesOfType(trackType)
                   .setOverrideForType(TrackSelectionOverride(track.trackGroup, listOf(track.trackIndex)))
                   .setTrackTypeDisabled(trackType, false)
        }
        player.trackSelectionParameters = builder.build()
    }

    fun isVideoQualityAutoPreferred(): Boolean = prefersAutoVideoQuality

    /** Reset audio track override so the next onTracksChanged selects first audio (Russian). */
    fun resetAudioOverride() {
        appliedFirstAudioOverride = false
    }

    fun selectSpeed(speed: Float) {
        player.setPlaybackSpeed(speed)
        playbackSpeed = speed
    }

    override fun onPlaybackStateChanged(state: Int) {
        if (state == Player.STATE_READY) {
            reconcilePendingStartPosition()
            _uiState.update { it.copy(fileLoaded = true) }
        }
        if (state == Player.STATE_ENDED) eventsChannel.trySend(PlayerEvents.NavigateBack)
    }

    override fun onPlayerError(error: PlaybackException) {
        Log.e("PlayerVM", "Player error: ${error.errorCodeName}", error)
        if (shouldFallbackToSoftwareDecoder(error)) {
            fallbackToSoftwareDecoder()
        }
    }

    private fun shouldFallbackToSoftwareDecoder(error: PlaybackException): Boolean {
        if (preferSoftwareDecoder || !useExo) return false
        return when (error.errorCode) {
            PlaybackException.ERROR_CODE_DECODING_FAILED,
            PlaybackException.ERROR_CODE_DECODER_INIT_FAILED,
            PlaybackException.ERROR_CODE_DECODER_QUERY_FAILED,
            PlaybackException.ERROR_CODE_DECODING_FORMAT_EXCEEDS_CAPABILITIES,
            PlaybackException.ERROR_CODE_DECODING_FORMAT_UNSUPPORTED,
            PlaybackException.ERROR_CODE_VIDEO_FRAME_PROCESSING_FAILED,
            -> true
            else -> false
        }
    }

    private fun fallbackToSoftwareDecoder() {
        val args = lastInitArgs ?: return
        preferSoftwareDecoder = true

        val currentIndex = player.currentMediaItemIndex.coerceAtLeast(0)
        val currentPosition = player.currentPosition.coerceAtLeast(0L)
        val shouldPlay = player.playWhenReady

        Log.w(
            "PlayerVM",
            "Falling back to software decoder: index=$currentIndex position=$currentPosition"
        )

        player.removeListener(this)
        player.release()

        player = createPlayer(useExo, preferSoftwareDecoder)
        player.addListener(this)
        _playerEpoch.update { it + 1 }

        baseTitle = args.title?.takeIf { it.isNotBlank() } ?: ""
        kpId = args.kinopoiskId
        episodeVoiceNames = args.voiceNames.orEmpty()
        _uiState.update { it.copy(fileLoaded = false) }

        val mediaItems = args.urls.mapIndexed { index, url ->
            val displayName = args.names?.getOrNull(index).orEmpty()
            val extras = Bundle().apply { putString("display_name", displayName) }
            MediaItem.Builder()
                .setMediaId(url)
                .setUri(url)
                .setMediaMetadata(
                    MediaMetadata.Builder()
                        .setTitle(baseTitle)
                        .setExtras(extras)
                        .build()
                )
                .build()
        }

        val safeIndex = currentIndex.coerceIn(0, (mediaItems.size - 1).coerceAtLeast(0))
        player.setMediaItems(mediaItems, safeIndex, currentPosition)
        player.prepare()
        player.playWhenReady = shouldPlay
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        eventsChannel.trySend(PlayerEvents.IsPlayingChanged(isPlaying))
    }

    override fun onCleared() {
        super.onCleared()
        player.removeListener(this)
        player.release()
    }

    private fun reconcilePendingStartPosition() {
        val restoredPosition = pendingStartPositionMs ?: return
        pendingStartPositionMs = null

        val duration = player.duration
        if (duration <= 0L) return

        val progressKey = pendingProgressKey
        pendingProgressKey = null

        val restartThresholdMs = minOf(60_000L, duration / 50)
        val shouldRestartFromBeginning = restoredPosition >= duration || restoredPosition >= (duration - restartThresholdMs)

        if (shouldRestartFromBeginning) {
            Log.d(
                "PlayerVM",
                "Resetting restored progress near the end: restored=$restoredPosition duration=$duration key=$progressKey"
            )
            player.seekTo(0L)
            if (!progressKey.isNullOrBlank()) {
                prefs.edit().putLong(progressKey, 0L).apply()
            }
        }
    }
}

private object PlayerCacheStore {
    @Volatile private var downloadCache: SimpleCache? = null
    @Volatile private var databaseProvider: DatabaseProvider? = null

    fun getDatabaseProvider(context: Context): DatabaseProvider {
        val current = databaseProvider
        if (current != null) return current
        return synchronized(this) {
            databaseProvider ?: StandaloneDatabaseProvider(context.applicationContext).also {
                databaseProvider = it
            }
        }
    }

    fun getDownloadCache(context: Context): SimpleCache {
        val current = downloadCache
        if (current != null) return current
        return synchronized(this) {
            downloadCache ?: run {
                val cacheDir = File(context.applicationContext.filesDir, "downloads/cache")
                SimpleCache(
                    cacheDir,
                    NoOpCacheEvictor(),
                    getDatabaseProvider(context)
                ).also { downloadCache = it }
            }
        }
    }
}

private class LoggingDataSourceFactory(
    private val delegate: DataSource.Factory,
    private val headers: Map<String, String>,
) : DataSource.Factory {
    override fun createDataSource(): DataSource {
        return LoggingDataSource(delegate.createDataSource(), headers)
    }
}

private class LoggingDataSource(
    private val delegate: DataSource,
    private val headers: Map<String, String>,
) : DataSource by delegate {
    override fun open(dataSpec: DataSpec): Long {
        val uri = dataSpec.uri.toString()
        if (uri.startsWith("http://") || uri.startsWith("https://")) {
            Log.d(
                "PlayerVM",
                "Opening HTTP dataSpec: uri=$uri headers=$headers"
            )
        } else {
            Log.d("PlayerVM", "Opening local dataSpec: uri=$uri")
        }
        return delegate.open(dataSpec)
    }
}

sealed interface PlayerEvents {
    data object NavigateBack : PlayerEvents
    data class IsPlayingChanged(val isPlaying: Boolean) : PlayerEvents
    data class PlayWhenReadyChanged(val playWhenReady: Boolean, val reason: Int) : PlayerEvents
}

data class SelectableTrack(
    val label: String,
    val formatId: String?,
    val trackGroup: TrackGroup,
    val trackIndex: Int,
    val isSelected: Boolean,
    val isSupported: Boolean,
    val height: Int = 0 // Added for easier sorting
)
