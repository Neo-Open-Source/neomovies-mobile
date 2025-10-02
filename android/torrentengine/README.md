# TorrentEngine Library

Либа для моего клиента и других независимых проектов где нужен простой торрент движок.

## Установка

### 1. Добавьте модуль в `settings.gradle.kts`:

```kotlin
include(":torrentengine")
```

### 2. Добавьте зависимость в `app/build.gradle.kts`:

```kotlin
dependencies {
    implementation(project(":torrentengine"))
}
```

### 3. Добавьте permissions в `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

## Использование

### Инициализация

```kotlin
val torrentEngine = TorrentEngine.getInstance(context)
torrentEngine.startStatsUpdater() // Запустить обновление статистики
```

### Добавление торрента

```kotlin
lifecycleScope.launch {
    try {
        val magnetUri = "magnet:?xt=urn:btih:..."
        val savePath = "${context.getExternalFilesDir(null)}/downloads"
        
        val infoHash = torrentEngine.addTorrent(magnetUri, savePath)
        Log.d("Torrent", "Added: $infoHash")
    } catch (e: Exception) {
        Log.e("Torrent", "Failed to add", e)
    }
}
```

### Получение списка торрентов (реактивно)

```kotlin
lifecycleScope.launch {
    torrentEngine.getAllTorrentsFlow().collect { torrents ->
        torrents.forEach { torrent ->
            println("${torrent.name}: ${torrent.progress * 100}%")
            println("Speed: ${torrent.downloadSpeed} B/s")
            println("Peers: ${torrent.numPeers}, Seeds: ${torrent.numSeeds}")
            println("ETA: ${torrent.getFormattedEta()}")
        }
    }
}
```

### Управление файлами в раздаче

```kotlin
lifecycleScope.launch {
    // Получить информацию о торренте
    val torrent = torrentEngine.getTorrent(infoHash)
    
    torrent?.files?.forEachIndexed { index, file ->
        println("File $index: ${file.path} (${file.size} bytes)")
        
        // Выбрать только видео файлы
        if (file.isVideo()) {
            torrentEngine.setFilePriority(infoHash, index, FilePriority.HIGH)
        } else {
            torrentEngine.setFilePriority(infoHash, index, FilePriority.DONT_DOWNLOAD)
        }
    }
}
```

### Пауза/Возобновление/Удаление

```kotlin
lifecycleScope.launch {
    // Поставить на паузу
    torrentEngine.pauseTorrent(infoHash)
    
    // Возобновить
    torrentEngine.resumeTorrent(infoHash)
    
    // Удалить (с файлами или без)
    torrentEngine.removeTorrent(infoHash, deleteFiles = true)
}
```

### Множественное изменение приоритетов

```kotlin
lifecycleScope.launch {
    val priorities = mapOf(
        0 to FilePriority.MAXIMUM,  // Первый файл - максимальный приоритет
        1 to FilePriority.HIGH,      // Второй - высокий
        2 to FilePriority.DONT_DOWNLOAD // Третий - не загружать
    )
    
    torrentEngine.setFilePriorities(infoHash, priorities)
}
```

## Модели данных

### TorrentInfo

```kotlin
data class TorrentInfo(
    val infoHash: String,
    val magnetUri: String,
    val name: String,
    val totalSize: Long,
    val downloadedSize: Long,
    val uploadedSize: Long,
    val downloadSpeed: Int,
    val uploadSpeed: Int,
    val progress: Float,
    val state: TorrentState,
    val numPeers: Int,
    val numSeeds: Int,
    val savePath: String,
    val files: List<TorrentFile>,
    val addedDate: Long,
    val finishedDate: Long?,
    val error: String?
)
```

### TorrentState

```kotlin
enum class TorrentState {
    STOPPED,
    QUEUED,
    METADATA_DOWNLOADING,
    CHECKING,
    DOWNLOADING,
    SEEDING,
    FINISHED,
    ERROR
}
```

### FilePriority

```kotlin
enum class FilePriority(val value: Int) {
    DONT_DOWNLOAD(0),  // Не загружать
    LOW(1),            // Низкий приоритет
    NORMAL(4),         // Обычный (по умолчанию)
    HIGH(6),           // Высокий
    MAXIMUM(7)         // Максимальный (загружать первым)
}
```

## Foreground Service

Сервис автоматически запускается при добавлении торрента и показывает постоянное уведомление с:
- Количеством активных торрентов
- Общей скоростью загрузки/отдачи
- Списком загружающихся файлов с прогрессом
- Кнопками управления (Pause All)

Уведомление **нельзя закрыть** пока есть активные торренты.

## Персистентность

Все торренты сохраняются в Room database и автоматически восстанавливаются при перезапуске приложения.

### Проверка видео файлов

```kotlin
val videoFiles = torrent.files.filter { it.isVideo() }
```

### Получение share ratio

```kotlin
val ratio = torrent.getShareRatio()
```

### Подсчет выбранных файлов

```kotlin
val selectedCount = torrent.getSelectedFilesCount()
val selectedSize = torrent.getSelectedSize()
```

[Apache License 2.0](LICENSE).

Made with <3 by Erno/Foxix