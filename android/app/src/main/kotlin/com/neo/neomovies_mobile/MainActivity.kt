package com.neo.neomovies_mobile

import android.os.Bundle
import android.util.Log
import com.google.gson.Gson
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
    private val torrentMetadataService = TorrentMetadataService()
    private val gson = Gson()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TORRENT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "parseMagnetBasicInfo" -> {
                        val magnetUri = call.argument<String>("magnetUri")
                        if (magnetUri != null) parseMagnetBasicInfo(magnetUri, result)
                        else result.error("INVALID_ARGUMENT", "magnetUri is required", null)
                    }
                    "fetchFullMetadata" -> {
                        val magnetUri = call.argument<String>("magnetUri")
                        if (magnetUri != null) fetchFullMetadata(magnetUri, result)
                        else result.error("INVALID_ARGUMENT", "magnetUri is required", null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun parseMagnetBasicInfo(magnetUri: String, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val basicInfo = torrentMetadataService.parseMagnetBasicInfo(magnetUri)
                if (basicInfo != null) {
                    result.success(gson.toJson(basicInfo))
                } else {
                    result.error("PARSE_ERROR", "Failed to parse magnet URI", null)
                }
            } catch (e: Exception) {
                result.error("EXCEPTION", e.message, null)
            }
        }
    }

    private fun fetchFullMetadata(magnetUri: String, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val metadata = torrentMetadataService.fetchFullMetadata(magnetUri)
                if (metadata != null) {
                    TorrentDisplayUtils.logTorrentStructure(metadata)
                    result.success(gson.toJson(metadata))
                } else {
                    result.error("METADATA_ERROR", "Failed to fetch torrent metadata", null)
                }
            } catch (e: Exception) {
                result.error("EXCEPTION", e.message, null)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        coroutineScope.cancel()
        torrentMetadataService.cleanup()
    }
}