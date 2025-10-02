package com.neo.neomovies_mobile

/**
 * Базовая информация из magnet-ссылки
 */
data class MagnetBasicInfo(
    val name: String,
    val infoHash: String,
    val trackers: List<String> = emptyList(),
    val totalSize: Long = 0L
)

/**
 * Полные метаданные торрента
 */
data class TorrentMetadata(
    val name: String,
    val infoHash: String,
    val totalSize: Long,
    val pieceLength: Int,
    val numPieces: Int,
    val fileStructure: FileStructure,
    val trackers: List<String> = emptyList(),
    val creationDate: Long = 0L,
    val comment: String = "",
    val createdBy: String = ""
)

/**
 * Структура файлов торрента
 */
data class FileStructure(
    val rootDirectory: DirectoryNode,
    val totalFiles: Int,
    val totalSize: Long,
    val filesByType: Map<String, Int> = emptyMap(),
    val fileTypeStats: Map<String, Int> = emptyMap()
)

/**
 * Узел директории в структуре файлов
 */
data class DirectoryNode(
    val name: String,
    val path: String,
    val files: List<FileInfo> = emptyList(),
    val subdirectories: List<DirectoryNode> = emptyList(),
    val totalSize: Long = 0L,
    val fileCount: Int = 0
)

/**
 * Информация о файле
 */
data class FileInfo(
    val name: String,
    val path: String,
    val size: Long,
    val index: Int,
    val extension: String = "",
    val isVideo: Boolean = false,
    val isAudio: Boolean = false,
    val isImage: Boolean = false,
    val isDocument: Boolean = false,
    val isArchive: Boolean = false
)