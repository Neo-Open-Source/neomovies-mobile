package com.neomovies.torrentengine

import android.content.Context
import android.content.Intent
import android.util.Log
import com.neomovies.torrentengine.database.TorrentDao
import com.neomovies.torrentengine.database.TorrentDatabase
import com.neomovies.torrentengine.models.*
import com.neomovies.torrentengine.service.TorrentService
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import org.libtorrent4j.*
import org.libtorrent4j.alerts.*
import java.io.File

/**
 * Main TorrentEngine class - the core of the torrent library
 * This is the main API that applications should use
 * 
 * Usage:
 * ```
 * val engine = TorrentEngine.getInstance(context)
 * engine.addTorrent(magnetUri, savePath)
 * ```
 */
class TorrentEngine private constructor(private val context: Context) {
    private val TAG = "TorrentEngine"
    
    // LibTorrent session
    private var session: SessionManager? = null
    private var isSessionStarted = false
    
    // Database
    private val database: TorrentDatabase = TorrentDatabase.getDatabase(context)
    private val torrentDao: TorrentDao = database.torrentDao()
    
    // Coroutine scope
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // Active torrent handles
    private val torrentHandles = mutableMapOf<String, TorrentHandle>()
    
    // Settings
    private val settings = SettingsPack().apply {
        setInteger(SettingsPack.Key.ALERT_MASK.value(), Alert.Category.ALL.swig())
        setBoolean(SettingsPack.Key.ENABLE_DHT.value(), true)
        setBoolean(SettingsPack.Key.ENABLE_LSD.value(), true)
        setString(SettingsPack.Key.USER_AGENT.value(), "NeoMovies/1.0 libtorrent4j/2.1.0")
    }

    init {
        startSession()
        restoreTorrents()
        startAlertListener()
    }

    /**
     * Start LibTorrent session
     */
    private fun startSession() {
        try {
            session = SessionManager()
            session?.start(settings)
            isSessionStarted = true
            Log.d(TAG, "LibTorrent session started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start session", e)
        }
    }

    /**
     * Restore torrents from database on startup
     */
    private fun restoreTorrents() {
        scope.launch {
            try {
                val torrents = torrentDao.getAllTorrents()
                Log.d(TAG, "Restoring ${torrents.size} torrents from database")
                
                torrents.forEach { torrent ->
                    if (torrent.state in arrayOf(TorrentState.DOWNLOADING, TorrentState.SEEDING)) {
                        // Resume active torrents
                        addTorrentInternal(torrent.magnetUri, torrent.savePath, torrent)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to restore torrents", e)
            }
        }
    }

    /**
     * Start alert listener for torrent events
     */
    private fun startAlertListener() {
        scope.launch {
            while (isActive && isSessionStarted) {
                try {
                    session?.let { sess ->
                        val alerts = sess.popAlerts()
                        for (alert in alerts) {
                            handleAlert(alert)
                        }
                    }
                    delay(1000) // Check every second
                } catch (e: Exception) {
                    Log.e(TAG, "Error in alert listener", e)
                }
            }
        }
    }

    /**
     * Handle LibTorrent alerts
     */
    private fun handleAlert(alert: Alert<*>) {
        when (alert.type()) {
            AlertType.METADATA_RECEIVED -> handleMetadataReceived(alert as MetadataReceivedAlert)
            AlertType.TORRENT_FINISHED -> handleTorrentFinished(alert as TorrentFinishedAlert)
            AlertType.TORRENT_ERROR -> handleTorrentError(alert as TorrentErrorAlert)
            AlertType.STATE_CHANGED -> handleStateChanged(alert as StateChangedAlert)
            AlertType.TORRENT_CHECKED -> handleTorrentChecked(alert as TorrentCheckedAlert)
            else -> { /* Ignore other alerts */ }
        }
    }

    /**
     * Handle metadata received (from magnet link)
     */
    private fun handleMetadataReceived(alert: MetadataReceivedAlert) {
        scope.launch {
            try {
                val handle = alert.handle()
                val infoHash = handle.infoHash().toHex()
                
                Log.d(TAG, "Metadata received for $infoHash")
                
                // Extract file information
                val torrentInfo = handle.torrentFile()
                val files = mutableListOf<TorrentFile>()
                
                for (i in 0 until torrentInfo.numFiles()) {
                    val fileStorage = torrentInfo.files()
                    files.add(
                        TorrentFile(
                            index = i,
                            path = fileStorage.filePath(i),
                            size = fileStorage.fileSize(i),
                            priority = FilePriority.NORMAL
                        )
                    )
                }
                
                // Update database
                val existingTorrent = torrentDao.getTorrent(infoHash)
                existingTorrent?.let {
                    torrentDao.updateTorrent(
                        it.copy(
                            name = torrentInfo.name(),
                            totalSize = torrentInfo.totalSize(),
                            files = files,
                            state = TorrentState.DOWNLOADING
                        )
                    )
                }
                
                torrentHandles[infoHash] = handle
            } catch (e: Exception) {
                Log.e(TAG, "Error handling metadata", e)
            }
        }
    }

    /**
     * Handle torrent finished
     */
    private fun handleTorrentFinished(alert: TorrentFinishedAlert) {
        scope.launch {
            val handle = alert.handle()
            val infoHash = handle.infoHash().toHex()
            Log.d(TAG, "Torrent finished: $infoHash")
            
            torrentDao.updateTorrentState(infoHash, TorrentState.FINISHED)
        }
    }

    /**
     * Handle torrent error
     */
    private fun handleTorrentError(alert: TorrentErrorAlert) {
        scope.launch {
            val handle = alert.handle()
            val infoHash = handle.infoHash().toHex()
            val error = alert.error().message()
            
            Log.e(TAG, "Torrent error: $infoHash - $error")
            torrentDao.setTorrentError(infoHash, error)
        }
    }

    /**
     * Handle state changed
     */
    private fun handleStateChanged(alert: StateChangedAlert) {
        scope.launch {
            val handle = alert.handle()
            val infoHash = handle.infoHash().toHex()
            val state = when (alert.state()) {
                TorrentStatus.State.CHECKING_FILES -> TorrentState.CHECKING
                TorrentStatus.State.DOWNLOADING_METADATA -> TorrentState.METADATA_DOWNLOADING
                TorrentStatus.State.DOWNLOADING -> TorrentState.DOWNLOADING
                TorrentStatus.State.FINISHED, TorrentStatus.State.SEEDING -> TorrentState.SEEDING
                else -> TorrentState.STOPPED
            }
            
            torrentDao.updateTorrentState(infoHash, state)
        }
    }

    /**
     * Handle torrent checked
     */
    private fun handleTorrentChecked(alert: TorrentCheckedAlert) {
        scope.launch {
            val handle = alert.handle()
            val infoHash = handle.infoHash().toHex()
            Log.d(TAG, "Torrent checked: $infoHash")
        }
    }

    /**
     * Add torrent from magnet URI
     * 
     * @param magnetUri Magnet link
     * @param savePath Directory to save files
     * @return Info hash of the torrent
     */
    suspend fun addTorrent(magnetUri: String, savePath: String): String {
        return withContext(Dispatchers.IO) {
            addTorrentInternal(magnetUri, savePath, null)
        }
    }

    /**
     * Internal method to add torrent
     */
    private suspend fun addTorrentInternal(
        magnetUri: String,
        savePath: String,
        existingTorrent: TorrentInfo?
    ): String {
        return withContext(Dispatchers.IO) {
            try {
                // Parse magnet URI
                val error = ErrorCode()
                val params = SessionHandle.parseMagnetUri(magnetUri, error)
                
                if (error.value() != 0) {
                    throw Exception("Invalid magnet URI: ${error.message()}")
                }
                
                val infoHash = params.infoHash().toHex()
                
                // Check if already exists
                val existing = existingTorrent ?: torrentDao.getTorrent(infoHash)
                if (existing != null && torrentHandles.containsKey(infoHash)) {
                    Log.d(TAG, "Torrent already exists: $infoHash")
                    return@withContext infoHash
                }
                
                // Set save path
                val saveDir = File(savePath)
                if (!saveDir.exists()) {
                    saveDir.mkdirs()
                }
                params.savePath(saveDir.absolutePath)
                
                // Add to session
                val handle = session?.swig()?.addTorrent(params, error)
                    ?: throw Exception("Session not initialized")
                
                if (error.value() != 0) {
                    throw Exception("Failed to add torrent: ${error.message()}")
                }
                
                torrentHandles[infoHash] = TorrentHandle(handle)
                
                // Save to database
                val torrentInfo = TorrentInfo(
                    infoHash = infoHash,
                    magnetUri = magnetUri,
                    name = existingTorrent?.name ?: "Loading...",
                    savePath = saveDir.absolutePath,
                    state = TorrentState.METADATA_DOWNLOADING
                )
                torrentDao.insertTorrent(torrentInfo)
                
                // Start foreground service
                startService()
                
                Log.d(TAG, "Torrent added: $infoHash")
                infoHash
            } catch (e: Exception) {
                Log.e(TAG, "Failed to add torrent", e)
                throw e
            }
        }
    }

    /**
     * Resume torrent
     */
    suspend fun resumeTorrent(infoHash: String) {
        withContext(Dispatchers.IO) {
            try {
                torrentHandles[infoHash]?.resume()
                torrentDao.updateTorrentState(infoHash, TorrentState.DOWNLOADING)
                startService()
                Log.d(TAG, "Torrent resumed: $infoHash")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to resume torrent", e)
            }
        }
    }

    /**
     * Pause torrent
     */
    suspend fun pauseTorrent(infoHash: String) {
        withContext(Dispatchers.IO) {
            try {
                torrentHandles[infoHash]?.pause()
                torrentDao.updateTorrentState(infoHash, TorrentState.STOPPED)
                Log.d(TAG, "Torrent paused: $infoHash")
                
                // Stop service if no active torrents
                if (torrentDao.getActiveTorrents().isEmpty()) {
                    stopService()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to pause torrent", e)
            }
        }
    }

    /**
     * Remove torrent
     * 
     * @param infoHash Torrent info hash
     * @param deleteFiles Whether to delete downloaded files
     */
    suspend fun removeTorrent(infoHash: String, deleteFiles: Boolean = false) {
        withContext(Dispatchers.IO) {
            try {
                val handle = torrentHandles[infoHash]
                if (handle != null) {
                    session?.remove(handle)
                    torrentHandles.remove(infoHash)
                }
                
                if (deleteFiles) {
                    val torrent = torrentDao.getTorrent(infoHash)
                    torrent?.let {
                        val dir = File(it.savePath)
                        if (dir.exists()) {
                            dir.deleteRecursively()
                        }
                    }
                }
                
                torrentDao.deleteTorrentByHash(infoHash)
                Log.d(TAG, "Torrent removed: $infoHash")
                
                // Stop service if no active torrents
                if (torrentDao.getActiveTorrents().isEmpty()) {
                    stopService()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to remove torrent", e)
            }
        }
    }

    /**
     * Set file priority in torrent
     * This allows selecting/deselecting files even after torrent is started
     * 
     * @param infoHash Torrent info hash
     * @param fileIndex File index
     * @param priority File priority
     */
    suspend fun setFilePriority(infoHash: String, fileIndex: Int, priority: FilePriority) {
        withContext(Dispatchers.IO) {
            try {
                val handle = torrentHandles[infoHash] ?: return@withContext
                handle.filePriority(fileIndex, Priority.getValue(priority.value))
                
                // Update database
                val torrent = torrentDao.getTorrent(infoHash) ?: return@withContext
                val updatedFiles = torrent.files.mapIndexed { index, file ->
                    if (index == fileIndex) file.copy(priority = priority) else file
                }
                torrentDao.updateTorrent(torrent.copy(files = updatedFiles))
                
                Log.d(TAG, "File priority updated: $infoHash, file $fileIndex, priority $priority")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to set file priority", e)
            }
        }
    }

    /**
     * Set multiple file priorities at once
     */
    suspend fun setFilePriorities(infoHash: String, priorities: Map<Int, FilePriority>) {
        withContext(Dispatchers.IO) {
            try {
                val handle = torrentHandles[infoHash] ?: return@withContext
                
                priorities.forEach { (fileIndex, priority) ->
                    handle.filePriority(fileIndex, Priority.getValue(priority.value))
                }
                
                // Update database
                val torrent = torrentDao.getTorrent(infoHash) ?: return@withContext
                val updatedFiles = torrent.files.mapIndexed { index, file ->
                    priorities[index]?.let { file.copy(priority = it) } ?: file
                }
                torrentDao.updateTorrent(torrent.copy(files = updatedFiles))
                
                Log.d(TAG, "Multiple file priorities updated: $infoHash")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to set file priorities", e)
            }
        }
    }

    /**
     * Get torrent info
     */
    suspend fun getTorrent(infoHash: String): TorrentInfo? {
        return torrentDao.getTorrent(infoHash)
    }

    /**
     * Get all torrents
     */
    suspend fun getAllTorrents(): List<TorrentInfo> {
        return torrentDao.getAllTorrents()
    }

    /**
     * Get torrents as Flow (reactive updates)
     */
    fun getAllTorrentsFlow(): Flow<List<TorrentInfo>> {
        return torrentDao.getAllTorrentsFlow()
    }

    /**
     * Update torrent statistics
     */
    private suspend fun updateTorrentStats() {
        withContext(Dispatchers.IO) {
            torrentHandles.forEach { (infoHash, handle) ->
                try {
                    val status = handle.status()
                    
                    torrentDao.updateTorrentProgress(
                        infoHash,
                        status.progress(),
                        status.totalDone()
                    )
                    
                    torrentDao.updateTorrentSpeeds(
                        infoHash,
                        status.downloadRate(),
                        status.uploadRate()
                    )
                    
                    torrentDao.updateTorrentPeers(
                        infoHash,
                        status.numPeers(),
                        status.numSeeds()
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Error updating torrent stats for $infoHash", e)
                }
            }
        }
    }

    /**
     * Start periodic stats update
     */
    fun startStatsUpdater() {
        scope.launch {
            while (isActive) {
                updateTorrentStats()
                delay(1000) // Update every second
            }
        }
    }

    /**
     * Start foreground service
     */
    private fun startService() {
        try {
            val intent = Intent(context, TorrentService::class.java)
            context.startForegroundService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start service", e)
        }
    }

    /**
     * Stop foreground service
     */
    private fun stopService() {
        try {
            val intent = Intent(context, TorrentService::class.java)
            context.stopService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop service", e)
        }
    }

    /**
     * Shutdown engine
     */
    fun shutdown() {
        scope.cancel()
        session?.stop()
        isSessionStarted = false
    }

    companion object {
        @Volatile
        private var INSTANCE: TorrentEngine? = null

        /**
         * Get TorrentEngine singleton instance
         */
        fun getInstance(context: Context): TorrentEngine {
            return INSTANCE ?: synchronized(this) {
                val instance = TorrentEngine(context.applicationContext)
                INSTANCE = instance
                instance
            }
        }
    }
}
