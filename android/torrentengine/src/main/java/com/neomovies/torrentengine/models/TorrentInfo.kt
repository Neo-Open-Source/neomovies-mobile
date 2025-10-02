package com.neomovies.torrentengine.models

import androidx.room.Entity
import androidx.room.PrimaryKey
import androidx.room.TypeConverters
import com.neomovies.torrentengine.database.Converters

/**
 * Torrent information model
 * Represents a torrent download with all its metadata
 */
@Entity(tableName = "torrents")
@TypeConverters(Converters::class)
data class TorrentInfo(
    @PrimaryKey
    val infoHash: String,
    val magnetUri: String,
    val name: String,
    val totalSize: Long = 0,
    val downloadedSize: Long = 0,
    val uploadedSize: Long = 0,
    val downloadSpeed: Int = 0,
    val uploadSpeed: Int = 0,
    val progress: Float = 0f,
    val state: TorrentState = TorrentState.STOPPED,
    val numPeers: Int = 0,
    val numSeeds: Int = 0,
    val savePath: String,
    val files: List<TorrentFile> = emptyList(),
    val addedDate: Long = System.currentTimeMillis(),
    val finishedDate: Long? = null,
    val error: String? = null,
    val sequentialDownload: Boolean = false,
    val isPrivate: Boolean = false,
    val creator: String? = null,
    val comment: String? = null,
    val trackers: List<String> = emptyList()
) {
    /**
     * Calculate ETA (Estimated Time of Arrival) in seconds
     */
    fun getEta(): Long {
        if (downloadSpeed == 0) return Long.MAX_VALUE
        val remainingBytes = totalSize - downloadedSize
        return remainingBytes / downloadSpeed
    }

    /**
     * Get formatted ETA string
     */
    fun getFormattedEta(): String {
        val eta = getEta()
        if (eta == Long.MAX_VALUE) return "∞"
        
        val hours = eta / 3600
        val minutes = (eta % 3600) / 60
        val seconds = eta % 60
        
        return when {
            hours > 0 -> String.format("%dh %02dm", hours, minutes)
            minutes > 0 -> String.format("%dm %02ds", minutes, seconds)
            else -> String.format("%ds", seconds)
        }
    }

    /**
     * Get share ratio
     */
    fun getShareRatio(): Float {
        if (downloadedSize == 0L) return 0f
        return uploadedSize.toFloat() / downloadedSize.toFloat()
    }

    /**
     * Check if torrent is active (downloading/seeding)
     */
    fun isActive(): Boolean = state in arrayOf(
        TorrentState.DOWNLOADING,
        TorrentState.SEEDING,
        TorrentState.METADATA_DOWNLOADING
    )

    /**
     * Check if torrent has error
     */
    fun hasError(): Boolean = error != null

    /**
     * Get selected files count
     */
    fun getSelectedFilesCount(): Int = files.count { it.priority > FilePriority.DONT_DOWNLOAD }

    /**
     * Get total selected size
     */
    fun getSelectedSize(): Long = files
        .filter { it.priority > FilePriority.DONT_DOWNLOAD }
        .sumOf { it.size }
}

/**
 * Torrent state enumeration
 */
enum class TorrentState {
    /**
     * Torrent is stopped/paused
     */
    STOPPED,

    /**
     * Torrent is queued for download
     */
    QUEUED,

    /**
     * Downloading metadata from magnet link
     */
    METADATA_DOWNLOADING,

    /**
     * Checking files on disk
     */
    CHECKING,

    /**
     * Actively downloading
     */
    DOWNLOADING,

    /**
     * Download finished, now seeding
     */
    SEEDING,

    /**
     * Finished downloading and seeding
     */
    FINISHED,

    /**
     * Error occurred
     */
    ERROR
}

/**
 * File information within torrent
 */
data class TorrentFile(
    val index: Int,
    val path: String,
    val size: Long,
    val downloaded: Long = 0,
    val priority: FilePriority = FilePriority.NORMAL,
    val progress: Float = 0f
) {
    /**
     * Get file name from path
     */
    fun getName(): String = path.substringAfterLast('/')

    /**
     * Get file extension
     */
    fun getExtension(): String = path.substringAfterLast('.', "")

    /**
     * Check if file is video
     */
    fun isVideo(): Boolean = getExtension().lowercase() in VIDEO_EXTENSIONS

    /**
     * Check if file is selected for download
     */
    fun isSelected(): Boolean = priority > FilePriority.DONT_DOWNLOAD

    companion object {
        private val VIDEO_EXTENSIONS = setOf(
            "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "3gp"
        )
    }
}

/**
 * File download priority
 */
enum class FilePriority(val value: Int) {
    /**
     * Don't download this file
     */
    DONT_DOWNLOAD(0),

    /**
     * Low priority
     */
    LOW(1),

    /**
     * Normal priority (default)
     */
    NORMAL(4),

    /**
     * High priority
     */
    HIGH(6),

    /**
     * Maximum priority (download first)
     */
    MAXIMUM(7);

    companion object {
        fun fromValue(value: Int): FilePriority = values().firstOrNull { it.value == value } ?: NORMAL
    }
}

/**
 * Torrent statistics for UI
 */
data class TorrentStats(
    val totalTorrents: Int = 0,
    val activeTorrents: Int = 0,
    val downloadingTorrents: Int = 0,
    val seedingTorrents: Int = 0,
    val pausedTorrents: Int = 0,
    val totalDownloadSpeed: Long = 0,
    val totalUploadSpeed: Long = 0,
    val totalDownloaded: Long = 0,
    val totalUploaded: Long = 0
) {
    /**
     * Get formatted download speed
     */
    fun getFormattedDownloadSpeed(): String = formatSpeed(totalDownloadSpeed)

    /**
     * Get formatted upload speed
     */
    fun getFormattedUploadSpeed(): String = formatSpeed(totalUploadSpeed)

    private fun formatSpeed(speed: Long): String {
        return when {
            speed >= 1024 * 1024 -> String.format("%.1f MB/s", speed / (1024.0 * 1024.0))
            speed >= 1024 -> String.format("%.1f KB/s", speed / 1024.0)
            else -> "$speed B/s"
        }
    }
}
