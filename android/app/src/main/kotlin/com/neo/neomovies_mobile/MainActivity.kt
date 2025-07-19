package com.example.neomovies_mobile

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import com.google.gson.Gson

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.neo.neomovies/torrent"
    private lateinit var torrentService: TorrentService
    private val gson = Gson()
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize torrent service
        torrentService = TorrentService(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTorrentMetadata" -> {
                    val magnetLink = call.argument<String>("magnetLink")
                    if (magnetLink != null) {
                        CoroutineScope(Dispatchers.Main).launch {
                            try {
                                val metadata = torrentService.getTorrentMetadata(magnetLink)
                                if (metadata.isSuccess) {
                                    result.success(gson.toJson(metadata.getOrNull()))
                                } else {
                                    result.error("METADATA_ERROR", metadata.exceptionOrNull()?.message, null)
                                }
                            } catch (e: Exception) {
                                result.error("METADATA_ERROR", e.message, null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "magnetLink is required", null)
                    }
                }
                
                "startDownload" -> {
                    val magnetLink = call.argument<String>("magnetLink")
                    val selectedFiles = call.argument<List<Int>>("selectedFiles")
                    val downloadPath = call.argument<String>("downloadPath")
                    
                    if (magnetLink != null && selectedFiles != null) {
                        CoroutineScope(Dispatchers.Main).launch {
                            try {
                                val downloadResult = torrentService.startDownload(magnetLink, selectedFiles, downloadPath)
                                if (downloadResult.isSuccess) {
                                    result.success(downloadResult.getOrNull())
                                } else {
                                    result.error("DOWNLOAD_ERROR", downloadResult.exceptionOrNull()?.message, null)
                                }
                            } catch (e: Exception) {
                                result.error("DOWNLOAD_ERROR", e.message, null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "magnetLink and selectedFiles are required", null)
                    }
                }
                
                "getDownloadProgress" -> {
                    val infoHash = call.argument<String>("infoHash")
                    if (infoHash != null) {
                        val progress = torrentService.getDownloadProgress(infoHash)
                        if (progress != null) {
                            result.success(gson.toJson(progress))
                        } else {
                            result.error("NOT_FOUND", "Download not found", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "infoHash is required", null)
                    }
                }
                
                "pauseDownload" -> {
                    val infoHash = call.argument<String>("infoHash")
                    if (infoHash != null) {
                        val success = torrentService.pauseDownload(infoHash)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "infoHash is required", null)
                    }
                }
                
                "resumeDownload" -> {
                    val infoHash = call.argument<String>("infoHash")
                    if (infoHash != null) {
                        val success = torrentService.resumeDownload(infoHash)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "infoHash is required", null)
                    }
                }
                
                "cancelDownload" -> {
                    val infoHash = call.argument<String>("infoHash")
                    if (infoHash != null) {
                        val success = torrentService.cancelDownload(infoHash)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "infoHash is required", null)
                    }
                }
                
                "getAllDownloads" -> {
                    val downloads = torrentService.getAllDownloads()
                    result.success(gson.toJson(downloads))
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        if (::torrentService.isInitialized) {
            torrentService.cleanup()
        }
    }
}
