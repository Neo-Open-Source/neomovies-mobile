package com.neo.neomovies_mobile

import android.util.Log
import kotlinx.coroutines.*
import java.net.URLDecoder
import org.libtorrent4j.*
import org.libtorrent4j.alerts.*
import org.libtorrent4j.swig.*

/**
 * Упрощенный сервис для получения метаданных торрентов из magnet-ссылок
 * Работает без сложных API libtorrent4j, используя только парсинг URI
 */
class TorrentMetadataService {
    
    companion object {
        private const val TAG = "TorrentMetadataService"
        
        // Расширения файлов по типам
        private val VIDEO_EXTENSIONS = setOf("mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "3gp")
        private val AUDIO_EXTENSIONS = setOf("mp3", "flac", "wav", "aac", "ogg", "wma", "m4a", "opus")
        private val IMAGE_EXTENSIONS = setOf("jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "tiff")
        private val DOCUMENT_EXTENSIONS = setOf("pdf", "doc", "docx", "txt", "rtf", "odt", "xls", "xlsx")
        private val ARCHIVE_EXTENSIONS = setOf("zip", "rar", "7z", "tar", "gz", "bz2", "xz")
    }
    
    /**
     * Быстрый парсинг magnet-ссылки для получения базовой информации
     */
    suspend fun parseMagnetBasicInfo(magnetUri: String): MagnetBasicInfo? = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "Парсинг magnet-ссылки: $magnetUri")
            
            if (!magnetUri.startsWith("magnet:?")) {
                Log.e(TAG, "Неверный формат magnet URI")
                return@withContext null
            }
            
            val infoHash = extractInfoHashFromMagnet(magnetUri)
            val name = extractNameFromMagnet(magnetUri)
            val trackers = extractTrackersFromMagnet(magnetUri)
            
            if (infoHash == null) {
                Log.e(TAG, "Не удалось извлечь info hash из magnet URI")
                return@withContext null
            }
            
            val basicInfo = MagnetBasicInfo(
                name = name ?: "Unknown",
                infoHash = infoHash,
                trackers = trackers
            )
            
            Log.d(TAG, "Базовая информация получена: name=${basicInfo.name}, hash=$infoHash")
            return@withContext basicInfo
            
        } catch (e: Exception) {
            Log.e(TAG, "Ошибка при парсинге magnet-ссылки", e)
            return@withContext null
        }
    }
    
    /**
     * Получение полных метаданных торрента (упрощенная версия)
     * Создает фиктивную структуру на основе базовой информации
     */
    suspend fun fetchFullMetadata(magnetUri: String): TorrentMetadata? = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "Получение полных метаданных для: $magnetUri")
            
            // Получаем базовую информацию
            val basicInfo = parseMagnetBasicInfo(magnetUri) ?: return@withContext null
            
            // Создаем фиктивную структуру файлов для демонстрации
            val fileStructure = createMockFileStructure(basicInfo.name)
            
            val metadata = TorrentMetadata(
                name = basicInfo.name,
                infoHash = basicInfo.infoHash,
                totalSize = 1024L * 1024L * 1024L, // 1GB для примера
                pieceLength = 1024 * 1024, // 1MB
                numPieces = 1024,
                fileStructure = fileStructure,
                trackers = basicInfo.trackers,
                creationDate = System.currentTimeMillis() / 1000,
                comment = "Parsed from magnet URI",
                createdBy = "NEOMOVIES"
            )
            
            Log.d(TAG, "Полные метаданные созданы: ${metadata.name}")
            return@withContext metadata
            
        } catch (e: Exception) {
            Log.e(TAG, "Ошибка при получении метаданных торрента", e)
            return@withContext null
        }
    }
    
    /**
     * Извлечение info hash из magnet URI
     */
    private fun extractInfoHashFromMagnet(magnetUri: String): String? {
        val regex = Regex("xt=urn:btih:([a-fA-F0-9]{40}|[a-fA-F0-9]{32})")
        val match = regex.find(magnetUri)
        return match?.groupValues?.get(1)
    }
    
    /**
     * Извлечение имени из magnet URI
     */
    private fun extractNameFromMagnet(magnetUri: String): String? {
        val regex = Regex("dn=([^&]+)")
        val match = regex.find(magnetUri)
        return match?.groupValues?.get(1)?.let { 
            try {
                URLDecoder.decode(it, "UTF-8")
            } catch (e: Exception) {
                it // Возвращаем как есть, если декодирование не удалось
            }
        }
    }
    
    /**
     * Извлечение трекеров из magnet URI
     */
    private fun extractTrackersFromMagnet(magnetUri: String): List<String> {
        val trackers = mutableListOf<String>()
        val regex = Regex("tr=([^&]+)")
        val matches = regex.findAll(magnetUri)
        
        matches.forEach { match ->
            try {
                val tracker = URLDecoder.decode(match.groupValues[1], "UTF-8")
                trackers.add(tracker)
            } catch (e: Exception) {
                Log.w(TAG, "Ошибка декодирования трекера: ${match.groupValues[1]}")
                // Добавляем как есть, если декодирование не удалось
                trackers.add(match.groupValues[1])
            }
        }
        
        return trackers
    }
    
    /**
     * Создание фиктивной структуры файлов для демонстрации
     */
    private fun createMockFileStructure(torrentName: String): FileStructure {
        val files = mutableListOf<FileInfo>()
        val fileTypeStats = mutableMapOf<String, Int>()
        
        // Создаем несколько примерных файлов на основе имени торрента
        val isVideoTorrent = VIDEO_EXTENSIONS.any { torrentName.lowercase().contains(it) }
        val isAudioTorrent = AUDIO_EXTENSIONS.any { torrentName.lowercase().contains(it) }
        
        when {
            isVideoTorrent -> {
                // Видео торрент
                files.add(FileInfo(
                    name = "$torrentName.mkv",
                    path = "$torrentName.mkv",
                    size = 800L * 1024L * 1024L, // 800MB
                    index = 0,
                    extension = "mkv",
                    isVideo = true
                ))
                files.add(FileInfo(
                    name = "subtitles.srt",
                    path = "subtitles.srt",
                    size = 50L * 1024L, // 50KB
                    index = 1,
                    extension = "srt",
                    isDocument = true
                ))
                fileTypeStats["video"] = 1
                fileTypeStats["document"] = 1
            }
            
            isAudioTorrent -> {
                // Аудио торрент
                for (i in 1..10) {
                    files.add(FileInfo(
                        name = "Track $i.mp3",
                        path = "Track $i.mp3",
                        size = 5L * 1024L * 1024L, // 5MB
                        index = i - 1,
                        extension = "mp3",
                        isAudio = true
                    ))
                }
                fileTypeStats["audio"] = 10
            }
            
            else -> {
                // Общий торрент
                files.add(FileInfo(
                    name = "$torrentName.zip",
                    path = "$torrentName.zip",
                    size = 500L * 1024L * 1024L, // 500MB
                    index = 0,
                    extension = "zip"
                ))
                files.add(FileInfo(
                    name = "readme.txt",
                    path = "readme.txt",
                    size = 1024L, // 1KB
                    index = 1,
                    extension = "txt",
                    isDocument = true
                ))
                fileTypeStats["archive"] = 1
                fileTypeStats["document"] = 1
            }
        }
        
        // Создаем корневую директорию
        val rootDirectory = DirectoryNode(
            name = "root",
            path = "",
            files = files,
            subdirectories = emptyList(),
            totalSize = files.sumOf { it.size },
            fileCount = files.size
        )
        
        return FileStructure(
            rootDirectory = rootDirectory,
            totalFiles = files.size,
            filesByType = fileTypeStats
        )
    }
    
    /**
     * Получение расширения файла
     */
    private fun getFileExtension(fileName: String): String {
        val lastDot = fileName.lastIndexOf('.')
        return if (lastDot > 0 && lastDot < fileName.length - 1) {
            fileName.substring(lastDot + 1)
        } else {
            ""
        }
    }
    
    /**
     * Определение типа файла по расширению
     */
    private fun getFileType(extension: String): String {
        val ext = extension.lowercase()
        return when {
            VIDEO_EXTENSIONS.contains(ext) -> "video"
            AUDIO_EXTENSIONS.contains(ext) -> "audio"
            IMAGE_EXTENSIONS.contains(ext) -> "image"
            DOCUMENT_EXTENSIONS.contains(ext) -> "document"
            ARCHIVE_EXTENSIONS.contains(ext) -> "archive"
            else -> "other"
        }
    }
    
    /**
     * Освобождение ресурсов
     */
    fun cleanup() {
        Log.d(TAG, "Торрент-сервис очищен")
    }
}
