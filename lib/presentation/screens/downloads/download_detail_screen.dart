import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/downloads_provider.dart';
import '../player/native_video_player_screen.dart';
import '../player/webview_player_screen.dart';

class DownloadDetailScreen extends StatefulWidget {
  final ActiveDownload download;

  const DownloadDetailScreen({
    super.key,
    required this.download,
  });

  @override
  State<DownloadDetailScreen> createState() => _DownloadDetailScreenState();
}

class _DownloadDetailScreenState extends State<DownloadDetailScreen> {
  List<DownloadedFile> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadedFiles();
  }

  Future<void> _loadDownloadedFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get downloads directory
      final downloadsDir = await getApplicationDocumentsDirectory();
      final torrentDir = Directory('${downloadsDir.path}/torrents/${widget.download.infoHash}');

      if (await torrentDir.exists()) {
        final files = await _scanDirectory(torrentDir);
        setState(() {
          _files = files;
          _isLoading = false;
        });
      } else {
        setState(() {
          _files = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _files = [];
        _isLoading = false;
      });
    }
  }

  Future<List<DownloadedFile>> _scanDirectory(Directory directory) async {
    final List<DownloadedFile> files = [];
    
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final stat = await entity.stat();
        final fileName = entity.path.split('/').last;
        final extension = fileName.split('.').last.toLowerCase();
        
        files.add(DownloadedFile(
          name: fileName,
          path: entity.path,
          size: stat.size,
          isVideo: _isVideoFile(extension),
          isAudio: _isAudioFile(extension),
          extension: extension,
        ));
      }
    }
    
    return files..sort((a, b) => a.name.compareTo(b.name));
  }

  bool _isVideoFile(String extension) {
    const videoExtensions = ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v'];
    return videoExtensions.contains(extension);
  }

  bool _isAudioFile(String extension) {
    const audioExtensions = ['mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg'];
    return audioExtensions.contains(extension);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.download.name),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDownloadedFiles,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressSection(),
          const Divider(height: 1),
          Expanded(
            child: _buildFilesSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    final progress = widget.download.progress;
    final isCompleted = progress.progress >= 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Прогресс загрузки',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress.progress * 100).toStringAsFixed(1)}% - ${progress.state}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCompleted 
                    ? Colors.green.withOpacity(0.1)
                    : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isCompleted ? 'Завершено' : 'Загружается',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isCompleted ? Colors.green : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress.progress,
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              isCompleted ? Colors.green : Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildProgressStat('Скорость', '${_formatSpeed(progress.downloadRate)}'),
              const SizedBox(width: 24),
              _buildProgressStat('Сиды', '${progress.numSeeds}'),
              const SizedBox(width: 24),
              _buildProgressStat('Пиры', '${progress.numPeers}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFilesSection() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Сканирование файлов...'),
          ],
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Файлы не найдены',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Возможно, загрузка еще не завершена',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Файлы (${_files.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _files.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final file = _files[index];
              return _buildFileItem(file);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileItem(DownloadedFile file) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: file.isVideo || file.isAudio ? () => _openFile(file) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildFileIcon(file),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatFileSize(file.size),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _handleFileAction(value, file),
                itemBuilder: (context) => [
                  if (file.isVideo || file.isAudio) ...[
                    const PopupMenuItem(
                      value: 'play_native',
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow),
                          SizedBox(width: 8),
                          Text('Нативный плеер'),
                        ],
                      ),
                    ),
                    if (file.isVideo) ...[
                      const PopupMenuItem(
                        value: 'play_vibix',
                        child: Row(
                          children: [
                            Icon(Icons.web),
                            SizedBox(width: 8),
                            Text('Vibix плеер'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'play_alloha',
                        child: Row(
                          children: [
                            Icon(Icons.web),
                            SizedBox(width: 8),
                            Text('Alloha плеер'),
                          ],
                        ),
                      ),
                    ],
                    const PopupMenuDivider(),
                  ],
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Удалить', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileIcon(DownloadedFile file) {
    IconData icon;
    Color color;

    if (file.isVideo) {
      icon = Icons.movie;
      color = Colors.blue;
    } else if (file.isAudio) {
      icon = Icons.music_note;
      color = Colors.orange;
    } else {
      icon = Icons.insert_drive_file;
      color = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }

  void _openFile(DownloadedFile file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NativeVideoPlayerScreen(
          filePath: file.path,
          title: file.name,
        ),
      ),
    );
  }

  void _handleFileAction(String action, DownloadedFile file) {
    switch (action) {
      case 'play_native':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => NativeVideoPlayerScreen(
              filePath: file.path,
              title: file.name,
            ),
          ),
        );
        break;
      case 'play_vibix':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WebViewPlayerScreen(
              url: 'https://vibix.org/player',
              title: file.name,
              playerType: 'vibix',
            ),
          ),
        );
        break;
      case 'play_alloha':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WebViewPlayerScreen(
              url: 'https://alloha.org/player',
              title: file.name,
              playerType: 'alloha',
            ),
          ),
        );
        break;
      case 'delete':
        _showDeleteDialog(file);
        break;
    }
  }

  void _showDeleteDialog(DownloadedFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить файл'),
        content: Text('Вы уверены, что хотите удалить файл "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteFile(file);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFile(DownloadedFile file) async {
    try {
      final fileToDelete = File(file.path);
      if (await fileToDelete.exists()) {
        await fileToDelete.delete();
        _loadDownloadedFiles(); // Refresh the list
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Файл "${file.name}" удален'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления файла: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatSpeed(int bytesPerSecond) {
    return '${_formatFileSize(bytesPerSecond)}/s';
  }
}

class DownloadedFile {
  final String name;
  final String path;
  final int size;
  final bool isVideo;
  final bool isAudio;
  final String extension;

  DownloadedFile({
    required this.name,
    required this.path,
    required this.size,
    required this.isVideo,
    required this.isAudio,
    required this.extension,
  });
}