package com.neo.neomovies_mobile

import android.util.Log
import kotlin.math.log
import kotlin.math.pow

object TorrentDisplayUtils {

    private const val TAG = "TorrentDisplay"

    /**
     * Выводит полную информацию о торренте в лог
     */
    fun logTorrentInfo(metadata: TorrentMetadata) {
        Log.d(TAG, "=== ИНФОРМАЦИЯ О ТОРРЕНТЕ ===")
        Log.d(TAG, "Название: ${metadata.name}")
        Log.d(TAG, "Хэш: ${metadata.infoHash}")
        Log.d(TAG, "Размер: ${formatFileSize(metadata.totalSize)}")
        Log.d(TAG, "Файлов: ${metadata.fileStructure.totalFiles}")
        Log.d(TAG, "Частей: ${metadata.numPieces}")
        Log.d(TAG, "Размер части: ${formatFileSize(metadata.pieceLength.toLong())}")
        Log.d(TAG, "Трекеров: ${metadata.trackers.size}")
        
        if (metadata.comment.isNotEmpty()) {
            Log.d(TAG, "Комментарий: ${metadata.comment}")
        }
        if (metadata.createdBy.isNotEmpty()) {
            Log.d(TAG, "Создано: ${metadata.createdBy}")
        }
        if (metadata.creationDate > 0) {
            Log.d(TAG, "Дата создания: ${java.util.Date(metadata.creationDate * 1000)}")
        }
        
        Log.d(TAG, "")
        logFileTypeStats(metadata.fileStructure)
        Log.d(TAG, "")
        logFileStructure(metadata.fileStructure)
        Log.d(TAG, "")
        logTrackerList(metadata.trackers)
    }

    /**
     * Выводит структуру файлов в виде дерева
     */
    fun logFileStructure(fileStructure: FileStructure) {
        Log.d(TAG, "=== СТРУКТУРА ФАЙЛОВ ===")
        logDirectoryNode(fileStructure.rootDirectory, "")
    }

    /**
     * Рекурсивно выводит узел директории
     */
    private fun logDirectoryNode(node: DirectoryNode, prefix: String) {
        if (node.name.isNotEmpty()) {
            Log.d(TAG, "$prefix${node.name}/")
        }
        
        val childPrefix = if (node.name.isEmpty()) prefix else "$prefix  "
        
        // Выводим поддиректории
        node.subdirectories.forEach { subDir ->
            Log.d(TAG, "$childPrefix├── ${subDir.name}/")
            logDirectoryNode(subDir, "$childPrefix│   ")
        }
        
        // Выводим файлы
        node.files.forEachIndexed { index, file ->
            val isLast = index == node.files.size - 1 && node.subdirectories.isEmpty()
            val symbol = if (isLast) "└──" else "├──"
            val fileInfo = "${file.name} (${formatFileSize(file.size)}) [${file.extension.uppercase()}]"
            Log.d(TAG, "$childPrefix$symbol $fileInfo")
        }
    }

    /**
     * Выводит статистику по типам файлов
     */
    fun logFileTypeStats(fileStructure: FileStructure) {
        Log.d(TAG, "=== СТАТИСТИКА ПО ТИПАМ ФАЙЛОВ ===")
        if (fileStructure.filesByType.isEmpty()) {
            Log.d(TAG, "Нет статистики по типам файлов")
            return
        }
        fileStructure.filesByType.forEach { (type, count) ->
            val percentage = (count.toFloat() / fileStructure.totalFiles * 100).toInt()
            Log.d(TAG, "${type.uppercase()}: $count файлов ($percentage%)")
        }
    }

    /**
     * Alias for MainActivity – just logs structure.
     */
    fun logTorrentStructure(metadata: TorrentMetadata) {
        logFileStructure(metadata.fileStructure)
    }

    /**
     * Выводит список трекеров
     */
    fun logTrackerList(trackers: List<String>) {
        if (trackers.isEmpty()) {
            Log.d(TAG, "=== ТРЕКЕРЫ === (нет трекеров)")
            return
        }
        
        Log.d(TAG, "=== ТРЕКЕРЫ ===")
        trackers.forEachIndexed { index, tracker ->
            Log.d(TAG, "${index + 1}. $tracker")
        }
    }

    /**
     * Возвращает текстовое представление структуры файлов
     */
    fun getFileStructureText(fileStructure: FileStructure): String {
        val sb = StringBuilder()
        sb.appendLine("${fileStructure.rootDirectory.name}/")
        appendDirectoryNode(fileStructure.rootDirectory, "", sb)
        return sb.toString()
    }

    /**
     * Рекурсивно добавляет узел директории в StringBuilder
     */
    private fun appendDirectoryNode(node: DirectoryNode, prefix: String, sb: StringBuilder) {
        val childPrefix = if (node.name.isEmpty()) prefix else "$prefix  "
        
        // Добавляем поддиректории
        node.subdirectories.forEach { subDir ->
            sb.appendLine("$childPrefix└── ${subDir.name}/")
            appendDirectoryNode(subDir, "$childPrefix    ", sb)
        }
        
        // Добавляем файлы
        node.files.forEachIndexed { index, file ->
            val isLast = index == node.files.size - 1 && node.subdirectories.isEmpty()
            val symbol = if (isLast) "└──" else "├──"
            val fileInfo = "${file.name} (${formatFileSize(file.size)})"
            sb.appendLine("$childPrefix$symbol $fileInfo")
        }
    }

    /**
     * Возвращает краткую статистику о торренте
     */
    fun getTorrentSummary(metadata: TorrentMetadata): String {
        return buildString {
            appendLine("Название: ${metadata.name}")
            appendLine("Размер: ${formatFileSize(metadata.totalSize)}")
            appendLine("Файлов: ${metadata.fileStructure.totalFiles}")
            appendLine("Хэш: ${metadata.infoHash}")
            
            if (metadata.fileStructure.filesByType.isNotEmpty()) {
                appendLine("\nТипы файлов:")
                metadata.fileStructure.filesByType.forEach { (type, count) ->
                    val percentage = (count.toFloat() / metadata.fileStructure.totalFiles * 100).toInt()
                    appendLine("  ${type.uppercase()}: $count ($percentage%)")
                }
            }
        }
    }

    /**
     * Форматирует размер файла в читаемый вид
     */
    fun formatFileSize(bytes: Long): String {
        if (bytes <= 0) return "0 B"
        val units = arrayOf("B", "KB", "MB", "GB", "TB")
        val digitGroups = (log(bytes.toDouble(), 1024.0)).toInt()
        return "%.1f %s".format(
            bytes / 1024.0.pow(digitGroups),
            units[digitGroups.coerceAtMost(units.lastIndex)]
        )
    }

    /**
     * Возвращает иконку для типа файла
     */
    fun getFileTypeIcon(extension: String): String {
        return when {
            extension in setOf("mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "3gp") -> "🎬"
            extension in setOf("mp3", "flac", "wav", "aac", "ogg", "wma", "m4a", "opus") -> "🎵"
            extension in setOf("jpg", "jpeg", "png", "gif", "bmp", "webp", "svg") -> "🖼️"
            extension in setOf("pdf", "doc", "docx", "txt", "rtf", "odt") -> "📄"
            extension in setOf("zip", "rar", "7z", "tar", "gz", "bz2") -> "📦"
            else -> "📁"
        }
    }

    /**
     * Фильтрует файлы по типу
     */
    fun filterFilesByType(files: List<FileInfo>, type: String): List<FileInfo> {
        return when (type.lowercase()) {
            "video" -> files.filter { it.isVideo }
            "audio" -> files.filter { it.isAudio }
            "image" -> files.filter { it.isImage }
            "document" -> files.filter { it.isDocument }
            "archive" -> files.filter { it.isArchive }
            else -> files
        }
    }
}