package com.example.neomovies_mobile

import android.content.Context
import android.os.Environment
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import kotlinx.coroutines.*
import org.libtorrent4j.*
import org.libtorrent4j.alerts.*
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Data classes for torrent metadata
 */
data class TorrentFileInfo(
    @SerializedName("path") val path: String,
    @SerializedName("size") val size: Long,
    @SerializedName("selected") val selected: Boolean = false
)

data class TorrentMetadata(
    @SerializedName("name") val name: String,
    @SerializedName("totalSize") val totalSize: Long,
    @SerializedName("files") val files: List<TorrentFileInfo>,
    @SerializedName("infoHash") val infoHash: String
)

data class DownloadProgress(
    @SerializedName("infoHash") val infoHash: String,
    @SerializedName("progress") val progress: Float,
    @SerializedName("downloadRate") val downloadRate: Long,
    @SerializedName("uploadRate") val uploadRate: Long,
    @SerializedName("numSeeds") val numSeeds: Int,
    @SerializedName("numPeers") val numPeers: Int,
    @SerializedName("state") val state: String
)

/**
 * Torrent service using jlibtorrent for metadata extraction and downloading
 */
class TorrentService(private val context: Context) {
    private val gson = Gson()
    private var sessionManager: SessionManager? = null
    private val activeDownloads = mutableMapOf<String, TorrentHandle>()
    
    companion object {
        private const val METADATA_TIMEOUT_SECONDS = 30L
    }

    init {
        initializeSession()
    }

    private fun initializeSession() {
        try {
            sessionManager = SessionManager().apply {
                start()
                // Configure session settings for metadata-only downloads
                val settings = SettingsPacket().apply {
                    setString(settings_pack.string_types.user_agent.swigValue(), "NeoMovies/1.0")
                    setInt(settings_pack.int_types.alert_mask.swigValue(), 
                        AlertType.ERROR.swig() or 
                        AlertType.STORAGE.swig() or 
                        AlertType.STATUS.swig() or
                        AlertType.TORRENT.swig())
                }
                applySettings(settings)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Get torrent metadata from magnet link
     */
    suspend fun getTorrentMetadata(magnetLink: String): Result<TorrentMetadata> = withContext(Dispatchers.IO) {
        try {
            val session = sessionManager ?: return@withContext Result.failure(Exception("Session not initialized"))
            
            // Parse magnet link
            val params = SessionParams()
            val addTorrentParams = AddTorrentParams.parseMagnetUri(magnetLink, params)
            
            if (addTorrentParams == null) {
                return@withContext Result.failure(Exception("Invalid magnet link"))
            }

            // Set flags for metadata-only download
            addTorrentParams.flags = addTorrentParams.flags or TorrentFlags.UPLOAD_MODE.swig()
            
            // Add torrent to session
            val handle = session.addTorrent(addTorrentParams)
            val infoHash = handle.infoHash().toString()
            
            // Wait for metadata
            val latch = CountDownLatch(1)
            var metadata: TorrentMetadata? = null
            var error: Exception? = null
            
            val job = CoroutineScope(Dispatchers.IO).launch {
                try {
                    // Wait for metadata with timeout
                    val startTime = System.currentTimeMillis()
                    while (!handle.status().hasMetadata() && 
                           System.currentTimeMillis() - startTime < METADATA_TIMEOUT_SECONDS * 1000) {
                        delay(100)
                    }
                    
                    if (handle.status().hasMetadata()) {
                        val torrentInfo = handle.torrentFile()
                        val files = mutableListOf<TorrentFileInfo>()
                        
                        for (i in 0 until torrentInfo.numFiles()) {
                            val fileEntry = torrentInfo.fileAt(i)
                            files.add(TorrentFileInfo(
                                path = fileEntry.path(),
                                size = fileEntry.size(),
                                selected = false
                            ))
                        }
                        
                        metadata = TorrentMetadata(
                            name = torrentInfo.name(),
                            totalSize = torrentInfo.totalSize(),
                            files = files,
                            infoHash = infoHash
                        )
                    } else {
                        error = Exception("Metadata timeout")
                    }
                } catch (e: Exception) {
                    error = e
                } finally {
                    // Remove torrent from session (metadata only)
                    session.removeTorrent(handle)
                    latch.countDown()
                }
            }
            
            // Wait for completion
            latch.await(METADATA_TIMEOUT_SECONDS + 5, TimeUnit.SECONDS)
            job.cancel()
            
            metadata?.let { 
                Result.success(it) 
            } ?: Result.failure(error ?: Exception("Unknown error"))
            
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Start downloading selected files from torrent
     */
    suspend fun startDownload(
        magnetLink: String, 
        selectedFiles: List<Int>,
        downloadPath: String? = null
    ): Result<String> = withContext(Dispatchers.IO) {
        try {
            val session = sessionManager ?: return@withContext Result.failure(Exception("Session not initialized"))
            
            // Parse magnet link
            val params = SessionParams()
            val addTorrentParams = AddTorrentParams.parseMagnetUri(magnetLink, params)
            
            if (addTorrentParams == null) {
                return@withContext Result.failure(Exception("Invalid magnet link"))
            }

            // Set download path
            val savePath = downloadPath ?: getDefaultDownloadPath()
            addTorrentParams.savePath = savePath
            
            // Add torrent to session
            val handle = session.addTorrent(addTorrentParams)
            val infoHash = handle.infoHash().toString()
            
            // Wait for metadata first
            while (!handle.status().hasMetadata()) {
                delay(100)
            }
            
            // Set file priorities (only download selected files)
            val torrentInfo = handle.torrentFile()
            val priorities = IntArray(torrentInfo.numFiles()) { 0 } // 0 = don't download
            
            selectedFiles.forEach { fileIndex ->
                if (fileIndex < priorities.size) {
                    priorities[fileIndex] = 1 // 1 = normal priority
                }
            }
            
            handle.prioritizeFiles(priorities)
            handle.resume() // Start downloading
            
            // Store active download
            activeDownloads[infoHash] = handle
            
            Result.success(infoHash)
            
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Get download progress for a torrent
     */
    fun getDownloadProgress(infoHash: String): DownloadProgress? {
        val handle = activeDownloads[infoHash] ?: return null
        val status = handle.status()
        
        return DownloadProgress(
            infoHash = infoHash,
            progress = status.progress(),
            downloadRate = status.downloadRate().toLong(),
            uploadRate = status.uploadRate().toLong(),
            numSeeds = status.numSeeds(),
            numPeers = status.numPeers(),
            state = status.state().name
        )
    }

    /**
     * Pause download
     */
    fun pauseDownload(infoHash: String): Boolean {
        val handle = activeDownloads[infoHash] ?: return false
        handle.pause()
        return true
    }

    /**
     * Resume download
     */
    fun resumeDownload(infoHash: String): Boolean {
        val handle = activeDownloads[infoHash] ?: return false
        handle.resume()
        return true
    }

    /**
     * Cancel and remove download
     */
    fun cancelDownload(infoHash: String): Boolean {
        val handle = activeDownloads[infoHash] ?: return false
        sessionManager?.removeTorrent(handle)
        activeDownloads.remove(infoHash)
        return true
    }

    /**
     * Get all active downloads
     */
    fun getAllDownloads(): List<DownloadProgress> {
        return activeDownloads.map { (infoHash, _) ->
            getDownloadProgress(infoHash)
        }.filterNotNull()
    }

    private fun getDefaultDownloadPath(): String {
        return File(context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "NeoMovies").absolutePath
    }

    fun cleanup() {
        activeDownloads.clear()
        sessionManager?.stop()
        sessionManager = null
    }
}
