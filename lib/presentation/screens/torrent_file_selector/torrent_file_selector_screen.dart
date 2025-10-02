import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/services/torrent_platform_service.dart';

class TorrentFileSelectorScreen extends StatefulWidget {
  final String magnetLink;
  final String torrentTitle;

  const TorrentFileSelectorScreen({
    super.key,
    required this.magnetLink,
    required this.torrentTitle,
  });

  @override
  State<TorrentFileSelectorScreen> createState() => _TorrentFileSelectorScreenState();
}

class _TorrentFileSelectorScreenState extends State<TorrentFileSelectorScreen> {
  TorrentMetadataFull? _metadata;
  List<FileInfo> _files = [];
  bool _isLoading = true;
  String? _error;
  bool _isDownloading = false;
  bool _selectAll = false;
  MagnetBasicInfo? _basicInfo;

  @override
  void initState() {
    super.initState();
    _loadTorrentMetadata();
  }

  Future<void> _loadTorrentMetadata() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Сначала получаем базовую информацию
      _basicInfo = await TorrentPlatformService.parseMagnetBasicInfo(widget.magnetLink);
      
      // Затем пытаемся получить полные метаданные
      final metadata = await TorrentPlatformService.fetchFullMetadata(widget.magnetLink);
      
      setState(() {
        _metadata = metadata;
        _files = metadata.getAllFiles().map((file) => file.copyWith(selected: false)).toList();
        _isLoading = false;
      });
    } catch (e) {
      // Если не удалось получить полные метаданные, используем базовую информацию
      if (_basicInfo != null) {
        setState(() {
          _error = 'Не удалось получить полные метаданные. Показана базовая информация.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _toggleFileSelection(int index) {
    setState(() {
      _files[index] = _files[index].copyWith(selected: !_files[index].selected);
      _updateSelectAllState();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      _selectAll = !_selectAll;
      _files = _files.map((file) => file.copyWith(selected: _selectAll)).toList();
    });
  }

  void _updateSelectAllState() {
    final selectedCount = _files.where((file) => file.selected).length;
    _selectAll = selectedCount == _files.length;
  }

  Future<void> _startDownload() async {
    final selectedFiles = <int>[];
    for (int i = 0; i < _files.length; i++) {
      if (_files[i].selected) {
        selectedFiles.add(i);
      }
    }

    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите хотя бы один файл для скачивания'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final infoHash = await TorrentPlatformService.startDownload(
        magnetLink: widget.magnetLink,
        selectedFiles: selectedFiles,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Скачивание начато! ID: ${infoHash.substring(0, 8)}...'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка скачивания: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выбор файлов'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          if (!_isLoading && _files.isNotEmpty)
            TextButton(
              onPressed: _toggleSelectAll,
              child: Text(_selectAll ? 'Снять все' : 'Выбрать все'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header with torrent info
          _buildTorrentHeader(),
          
          // Content
          Expanded(
            child: _buildContent(),
          ),
          
          // Download button
          if (!_isLoading && _files.isNotEmpty && _metadata != null) _buildDownloadButton(),
        ],
      ),
    );
  }

  Widget _buildTorrentHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_zip,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.torrentTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_metadata != null) ...[
            const SizedBox(height: 8),
            Text(
              'Общий размер: ${_formatFileSize(_metadata!.totalSize)} • Файлов: ${_metadata!.fileStructure.totalFiles}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ] else if (_basicInfo != null) ...[
            const SizedBox(height: 8),
            Text(
              'Инфо хэш: ${_basicInfo!.infoHash.substring(0, 8)}... • Трекеров: ${_basicInfo!.trackers.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Получение информации о торренте...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              SelectableText.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Ошибка загрузки метаданных\n',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextSpan(
                      text: _error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loadTorrentMetadata,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_files.isEmpty && _basicInfo != null) {
      // Показываем базовую информацию о торренте
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Базовая информация о торренте',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Название: ${_basicInfo!.name}'),
                      const SizedBox(height: 8),
                      Text('Инфо хэш: ${_basicInfo!.infoHash}'),
                      const SizedBox(height: 8),
                      Text('Трекеров: ${_basicInfo!.trackers.length}'),
                      if (_basicInfo!.trackers.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Основной трекер: ${_basicInfo!.trackers.first}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loadTorrentMetadata,
                child: const Text('Получить полные метаданные'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_files.isEmpty) {
      return const Center(
        child: Text('Файлы не найдены'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final isDirectory = file.path.contains('/');
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: CheckboxListTile(
            value: file.selected,
            onChanged: (_) => _toggleFileSelection(index),
            title: Text(
              file.path.split('/').last,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDirectory) ...[
                  Text(
                    file.path.substring(0, file.path.lastIndexOf('/')),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  _formatFileSize(file.size),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            secondary: Icon(
              _getFileIcon(file.path),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
      },
    );
  }

  Widget _buildDownloadButton() {
    final selectedCount = _files.where((file) => file.selected).length;
    final selectedSize = _files
        .where((file) => file.selected)
        .fold<int>(0, (sum, file) => sum + file.size);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedCount > 0) ...[
              Text(
                'Выбрано: $selectedCount файл(ов) • ${_formatFileSize(selectedSize)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isDownloading ? null : _startDownload,
                icon: _isDownloading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(_isDownloading ? 'Начинаем скачивание...' : 'Скачать выбранные'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String path) {
    final extension = path.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
      case 'wmv':
        return Icons.movie;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return Icons.music_note;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'txt':
      case 'nfo':
        return Icons.description;
      case 'srt':
      case 'sub':
      case 'ass':
        return Icons.subtitles;
      default:
        return Icons.insert_drive_file;
    }
  }
}
