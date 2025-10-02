# TorrentEngine Library

Мощная библиотека для Android, обеспечивающая полноценную работу с торрентами через LibTorrent4j.

## 🎯 Возможности

- ✅ **Загрузка из magnet-ссылок** - получение метаданных и загрузка файлов
- ✅ **Выбор файлов** - возможность выбирать какие файлы загружать до и во время загрузки
- ✅ **Управление приоритетами** - изменение приоритета файлов в активной раздаче
- ✅ **Фоновый сервис** - непрерывная работа в фоне с foreground уведомлением
- ✅ **Постоянное уведомление** - нельзя закрыть пока активны загрузки
- ✅ **Персистентность** - сохранение состояния в Room database
- ✅ **Реактивность** - Flow API для мониторинга изменений
- ✅ **Полная статистика** - скорость, пиры, сиды, прогресс, ETA
- ✅ **Pause/Resume/Remove** - полный контроль над раздачами

## 📦 Установка

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

## 🚀 Использование

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

## 📊 Модели данных

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

## 🔔 Foreground Service

Сервис автоматически запускается при добавлении торрента и показывает постоянное уведомление с:
- Количеством активных торрентов
- Общей скоростью загрузки/отдачи
- Списком загружающихся файлов с прогрессом
- Кнопками управления (Pause All)

Уведомление **нельзя закрыть** пока есть активные торренты.

## 💾 Персистентность

Все торренты сохраняются в Room database и автоматически восстанавливаются при перезапуске приложения.

## 🔧 Расширенные возможности

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

## 📱 Интеграция с Flutter

Создайте MethodChannel для вызова из Flutter:

```kotlin
class TorrentEngineChannel(private val context: Context) {
    private val torrentEngine = TorrentEngine.getInstance(context)
    private val channel = "com.neomovies/torrent"
    
    fun setupMethodChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "addTorrent" -> {
                        val magnetUri = call.argument<String>("magnetUri")!!
                        val savePath = call.argument<String>("savePath")!!
                        
                        CoroutineScope(Dispatchers.IO).launch {
                            try {
                                val hash = torrentEngine.addTorrent(magnetUri, savePath)
                                result.success(hash)
                            } catch (e: Exception) {
                                result.error("ERROR", e.message, null)
                            }
                        }
                    }
                    // ... другие методы
                }
            }
    }
}
```

## 📄 Лицензия

MIT License - используйте свободно в любых проектах!

## 🤝 Вклад

Библиотека разработана как универсальное решение для работы с торрентами в Android.
Может использоваться в любых проектах без ограничений.

## 🐛 Известные проблемы

- LibTorrent4j требует минимум Android 5.0 (API 21)
- Для Android 13+ нужно запрашивать POST_NOTIFICATIONS permission
- Foreground service требует отображения уведомления

## 📞 Поддержка

При возникновении проблем создайте issue с описанием и логами.
