package com.neo.neomovies_mobile

import android.util.Log
import com.google.gson.Gson
import com.neomovies.torrentengine.TorrentEngine
import com.neomovies.torrentengine.models.FilePriority
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val TORRENT_CHANNEL = "com.neo.neomovies_mobile/torrent"
    }

    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val gson = Gson()
    private lateinit var torrentEngine: TorrentEngine

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize TorrentEngine
        torrentEngine = TorrentEngine.getInstance(applicationContext)
        torrentEngine.startStatsUpdater()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TORRENT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "addTorrent" -> {
                        val magnetUri = call.argument<String>("magnetUri")
                        val savePath = call.argument<String>("savePath")
                        if (magnetUri != null && savePath != null) {
                            addTorrent(magnetUri, savePath, result)
                        } else {
                            result.error("INVALID_ARGUMENT", "magnetUri and savePath are required", null)
                        }
                    }
                    "getTorrents" -> getTorrents(result)
                    "getTorrent" -> {
                        val infoHash = call.argument<String>("infoHash")
                        if (infoHash != null) getTorrent(infoHash, result)
                        else result.error("INVALID_ARGUMENT", "infoHash is required", null)
                    }
                    "pauseTorrent" -> {
                        val infoHash = call.argument<String>("infoHash")
                        if (infoHash != null) pauseTorrent(infoHash, result)
                        else result.error("INVALID_ARGUMENT", "infoHash is required", null)
                    }
                    "resumeTorrent" -> {
                        val infoHash = call.argument<String>("infoHash")
                        if (infoHash != null) resumeTorrent(infoHash, result)
                        else result.error("INVALID_ARGUMENT", "infoHash is required", null)
                    }
                    "removeTorrent" -> {
                        val infoHash = call.argument<String>("infoHash")
                        val deleteFiles = call.argument<Boolean>("deleteFiles") ?: false
                        if (infoHash != null) removeTorrent(infoHash, deleteFiles, result)
                        else result.error("INVALID_ARGUMENT", "infoHash is required", null)
                    }
                    "setFilePriority" -> {
                        val infoHash = call.argument<String>("infoHash")
                        val fileIndex = call.argument<Int>("fileIndex")
                        val priority = call.argument<Int>("priority")
                        if (infoHash != null && fileIndex != null && priority != null) {
                            setFilePriority(infoHash, fileIndex, priority, result)
                        } else {
                            result.error("INVALID_ARGUMENT", "infoHash, fileIndex, and priority are required", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun addTorrent(magnetUri: String, savePath: String, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val infoHash = withContext(Dispatchers.IO) {
                    torrentEngine.addTorrent(magnetUri, savePath)
                }
                result.success(infoHash)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to add torrent", e)
                result.error("ADD_TORRENT_ERROR", e.message, null)
            }
        }
    }

    private fun getTorrents(result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val torrents = withContext(Dispatchers.IO) {
                    torrentEngine.getAllTorrents()
                }
                val torrentsJson = torrents.map { torrent ->
                    mapOf(
                        "infoHash" to torrent.infoHash,
                        "name" to torrent.name,
                        "magnetUri" to torrent.magnetUri,
                        "totalSize" to torrent.totalSize,
                        "downloadedSize" to torrent.downloadedSize,
                        "uploadedSize" to torrent.uploadedSize,
                        "downloadSpeed" to torrent.downloadSpeed,
                        "uploadSpeed" to torrent.uploadSpeed,
                        "progress" to torrent.progress,
                        "state" to torrent.state.name,
                        "numPeers" to torrent.numPeers,
                        "numSeeds" to torrent.numSeeds,
                        "savePath" to torrent.savePath,
                        "files" to torrent.files.map { file ->
                            mapOf(
                                "index" to file.index,
                                "path" to file.path,
                                "size" to file.size,
                                "downloaded" to file.downloaded,
                                "priority" to file.priority.value,
                                "progress" to file.progress
                            )
                        },
                        "addedDate" to torrent.addedDate,
                        "error" to torrent.error
                    )
                }
                result.success(gson.toJson(torrentsJson))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get torrents", e)
                result.error("GET_TORRENTS_ERROR", e.message, null)
            }
        }
    }

    private fun getTorrent(infoHash: String, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val torrent = withContext(Dispatchers.IO) {
                    torrentEngine.getTorrent(infoHash)
                }
                if (torrent != null) {
                    val torrentJson = mapOf(
                        "infoHash" to torrent.infoHash,
                        "name" to torrent.name,
                        "magnetUri" to torrent.magnetUri,
                        "totalSize" to torrent.totalSize,
                        "downloadedSize" to torrent.downloadedSize,
                        "uploadedSize" to torrent.uploadedSize,
                        "downloadSpeed" to torrent.downloadSpeed,
                        "uploadSpeed" to torrent.uploadSpeed,
                        "progress" to torrent.progress,
                        "state" to torrent.state.name,
                        "numPeers" to torrent.numPeers,
                        "numSeeds" to torrent.numSeeds,
                        "savePath" to torrent.savePath,
                        "files" to torrent.files.map { file ->
                            mapOf(
                                "index" to file.index,
                                "path" to file.path,
                                "size" to file.size,
                                "downloaded" to file.downloaded,
                                "priority" to file.priority.value,
                                "progress" to file.progress
                            )
                        },
                        "addedDate" to torrent.addedDate,
                        "error" to torrent.error
                    )
                    result.success(gson.toJson(torrentJson))
                } else {
                    result.error("NOT_FOUND", "Torrent not found", null)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get torrent", e)
                result.error("GET_TORRENT_ERROR", e.message, null)
            }
        }
    }

    private fun pauseTorrent(infoHash: String, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                withContext(Dispatchers.IO) {
                    torrentEngine.pauseTorrent(infoHash)
                }
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to pause torrent", e)
                result.error("PAUSE_TORRENT_ERROR", e.message, null)
            }
        }
    }

    private fun resumeTorrent(infoHash: String, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                withContext(Dispatchers.IO) {
                    torrentEngine.resumeTorrent(infoHash)
                }
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to resume torrent", e)
                result.error("RESUME_TORRENT_ERROR", e.message, null)
            }
        }
    }

    private fun removeTorrent(infoHash: String, deleteFiles: Boolean, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                withContext(Dispatchers.IO) {
                    torrentEngine.removeTorrent(infoHash, deleteFiles)
                }
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to remove torrent", e)
                result.error("REMOVE_TORRENT_ERROR", e.message, null)
            }
        }
    }

    private fun setFilePriority(infoHash: String, fileIndex: Int, priorityValue: Int, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val priority = FilePriority.fromValue(priorityValue)
                withContext(Dispatchers.IO) {
                    torrentEngine.setFilePriority(infoHash, fileIndex, priority)
                }
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to set file priority", e)
                result.error("SET_PRIORITY_ERROR", e.message, null)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        coroutineScope.cancel()
        torrentEngine.shutdown()
    }
}