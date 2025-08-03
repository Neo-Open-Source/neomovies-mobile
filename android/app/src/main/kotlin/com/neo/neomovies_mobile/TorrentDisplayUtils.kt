package com.neo.neomovies_mobile

import android.util.Log
import kotlin.math.log
import kotlin.math.pow

object TorrentDisplayUtils {

    private const val TAG = "TorrentDisplay"

    fun logTorrentStructure(metadata: TorrentMetadata) {
        Log.d(TAG, "=== СТРУКТУРА ТОРРЕНТА ===")
        Log.d(TAG, "Название: ${metadata.name}")
        Log.d(TAG, "Хэш: ${metadata.infoHash}")
        Log.d(TAG, "Размер: ${formatFileSize(metadata.totalSize)}")
        Log.d(TAG, "Файлов: ${metadata.fileStructure.totalFiles}")
        Log.d(TAG, "Частей: ${metadata.numPieces}")
        Log.d(TAG, "Размер части: ${formatFileSize(metadata.pieceLength.toLong())}")
    }

    fun formatFileSize(bytes: Long): String {
        if (bytes <= 0) return "0 B"
        val units = arrayOf("B", "KB", "MB", "GB", "TB")
        val digitGroups = (log(bytes.toDouble(), 1024.0)).toInt()
        return "%.1f %s".format(
            bytes / 1024.0.pow(digitGroups),
            units[digitGroups.coerceAtMost(units.lastIndex)]
        )
    }
}