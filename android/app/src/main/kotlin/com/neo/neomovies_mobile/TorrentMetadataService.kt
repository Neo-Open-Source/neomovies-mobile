package com.neo.neomovies_mobile

import android.util.Log
import kotlinx.coroutines.Dispatchers
import org.libtorrent4j.AddTorrentParams
import kotlinx.coroutines.withContext
import org.libtorrent4j.*
import java.io.File
import java.util.concurrent.Executors

/**
 * Lightweight service that exposes exactly the API used by MainActivity.
 * - parseMagnetBasicInfo: quick parsing without network.
 * - fetchFullMetadata: downloads metadata and converts to TorrentMetadata.
 * - cleanup: stops internal SessionManager.
 */
object TorrentMetadataService {

    private const val TAG = "TorrentMetadataService"
    private val ioDispatcher = Dispatchers.IO

    /** Lazy SessionManager used for metadata fetch */
    private val session: SessionManager by lazy {
        SessionManager().apply { start(SessionParams(SettingsPack())) }
    }

    /** Parse basic info (name & hash) from magnet URI without contacting network */
    suspend fun parseMagnetBasicInfo(uri: String): MagnetBasicInfo? = withContext(ioDispatcher) {
        return@withContext try {
            MagnetBasicInfo(
                name = extractNameFromMagnet(uri),
                infoHash = extractHashFromMagnet(uri),
                trackers = emptyList<String>()
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse magnet", e)
            null
        }
    }

    /** Download full metadata from magnet link */
    suspend fun fetchFullMetadata(uri: String): TorrentMetadata? = withContext(ioDispatcher) {
        try {
            val data = session.fetchMagnet(uri, 30, File("/tmp")) ?: return@withContext null
            val ti = TorrentInfo(data)
            return@withContext buildMetadata(ti, uri)
        } catch (e: Exception) {
            Log.e(TAG, "Metadata fetch error", e)
            null
        }
    }

    fun cleanup() {
        if (session.isRunning) session.stop()
    }

    // --- helpers
    private fun extractNameFromMagnet(uri: String): String {
        val regex = "dn=([^&]+)".toRegex()
        val match = regex.find(uri)
        return match?.groups?.get(1)?.value?.let { java.net.URLDecoder.decode(it, "UTF-8") } ?: "Unknown"
    }

    private fun extractHashFromMagnet(uri: String): String {
        val regex = "btih:([A-Za-z0-9]{32,40})".toRegex()
        val match = regex.find(uri)
        return match?.groups?.get(1)?.value ?: ""
    }

    private fun buildMetadata(ti: TorrentInfo, originalUri: String): TorrentMetadata {
        val fs = ti.files()
        val list = MutableList(fs.numFiles()) { idx ->
            val size = fs.fileSize(idx)
            val path = fs.filePath(idx)
            val name = File(path).name
            val ext = name.substringAfterLast('.', "").lowercase()
            FileInfo(name, path, size, idx, ext)
        }
        val root = DirectoryNode(ti.name(), "", list)
        val structure = FileStructure(root, list.size, fs.totalSize())
        return TorrentMetadata(
            name = ti.name(),
            infoHash = extractHashFromMagnet(originalUri),
            totalSize = fs.totalSize(),
            pieceLength = ti.pieceLength(),
            numPieces = ti.numPieces(),
            fileStructure = structure
        )
    }
}
