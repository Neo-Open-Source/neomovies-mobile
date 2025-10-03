import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/downloads_provider.dart';
import '../../../data/models/torrent_info.dart';
import '../player/video_player_screen.dart';
import '../player/webview_player_screen.dart';
import 'package:auto_route/auto_route.dart';

@RoutePage()
class TorrentDetailScreen extends StatefulWidget {
  final String infoHash;

  const TorrentDetailScreen({
    super.key,
    required this.infoHash,
  });

  @override
  State<TorrentDetailScreen> createState() => _TorrentDetailScreenState();
}

class _TorrentDetailScreenState extends State<TorrentDetailScreen> {
  TorrentInfo? torrentInfo;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadTorrentInfo();
  }

  Future<void> _loadTorrentInfo() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final provider = context.read<DownloadsProvider>();
      final info = await provider.getTorrentInfo(widget.infoHash);
      
      setState(() {
        torrentInfo = info;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(torrentInfo?.name ?? 'Торрент'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        actions: [
          if (torrentInfo != null)
            PopupMenuButton<String>(
              onSelected: (value) => _handleAction(value),
              itemBuilder: (BuildContext context) => [
                if (torrentInfo!.isPaused)
                  const PopupMenuItem(
                    value: 'resume',
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow),
                        SizedBox(width: 8),
                        Text('Возобновить'),
                      ],
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: 'pause',
                    child: Row(
                      children: [
                        Icon(Icons.pause),
                        SizedBox(width: 8),
                        Text('Приостановить'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Обновить'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTorrentInfo,
              child: const Text('Попробовать снова'),
            ),
          ],
        ),
      );
    }

    if (torrentInfo == null) {
      return const Center(
        child: Text('Торрент не найден'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTorrentInfo(),
          const SizedBox(height: 24),
          _buildFilesSection(),
        ],
      ),
    );
  }

  Widget _buildTorrentInfo() {
    final torrent = torrentInfo!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Информация о торренте',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Название', torrent.name),
            _buildInfoRow('Размер', torrent.formattedTotalSize),
            _buildInfoRow('Прогресс', '${(torrent.progress * 100).toStringAsFixed(1)}%'),
            _buildInfoRow('Статус', _getStatusText(torrent)),
            _buildInfoRow('Путь сохранения', torrent.savePath),
            if (torrent.isDownloading || torrent.isSeeding) ...[
              const Divider(),
              _buildInfoRow('Скорость загрузки', torrent.formattedDownloadSpeed),
              _buildInfoRow('Скорость раздачи', torrent.formattedUploadSpeed),
              _buildInfoRow('Сиды', '${torrent.numSeeds}'),
              _buildInfoRow('Пиры', '${torrent.numPeers}'),
            ],
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: torrent.progress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                torrent.isCompleted
                    ? Colors.green.shade600
                    : Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(TorrentInfo torrent) {
    if (torrent.isCompleted) return 'Завершен';
    if (torrent.isDownloading) return 'Загружается';
    if (torrent.isPaused) return 'Приостановлен';
    if (torrent.isSeeding) return 'Раздача';
    return torrent.state;
  }

  Widget _buildFilesSection() {
    final torrent = torrentInfo!;
    final videoFiles = torrent.videoFiles;
    final otherFiles = torrent.files.where((file) => !videoFiles.contains(file)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Файлы',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        // Video files section
        if (videoFiles.isNotEmpty) ...[
          _buildFileTypeSection('Видео файлы', videoFiles, Icons.play_circle_fill),
          const SizedBox(height: 16),
        ],
        
        // Other files section
        if (otherFiles.isNotEmpty) ...[
          _buildFileTypeSection('Другие файлы', otherFiles, Icons.insert_drive_file),
        ],
      ],
    );
  }

  Widget _buildFileTypeSection(String title, List<TorrentFileInfo> files, IconData icon) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${files.length} файлов',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: files.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final file = files[index];
              return _buildFileItem(file, icon == Icons.play_circle_fill);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(TorrentFileInfo file, bool isVideo) {
    final fileName = file.path.split('/').last;
    final fileExtension = fileName.split('.').last.toUpperCase();
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isVideo 
            ? Colors.red.shade100 
            : Colors.blue.shade100,
        child: Text(
          fileExtension,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isVideo 
                ? Colors.red.shade700 
                : Colors.blue.shade700,
          ),
        ),
      ),
      title: Text(
        fileName,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatFileSize(file.size),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          if (file.progress > 0 && file.progress < 1.0) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: file.progress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ],
        ],
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) => _handleFileAction(value, file),
        itemBuilder: (BuildContext context) => [
          if (isVideo && file.progress >= 0.1) ...[
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
            const PopupMenuDivider(),
          ],
          PopupMenuItem(
            value: file.priority == FilePriority.DONT_DOWNLOAD ? 'download' : 'stop_download',
            child: Row(
              children: [
                Icon(file.priority == FilePriority.DONT_DOWNLOAD ? Icons.download : Icons.stop),
                const SizedBox(width: 8),
                Text(file.priority == FilePriority.DONT_DOWNLOAD ? 'Скачать' : 'Остановить'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'priority_${file.priority == FilePriority.HIGH ? 'normal' : 'high'}',
            child: Row(
              children: [
                Icon(file.priority == FilePriority.HIGH ? Icons.flag : Icons.flag_outlined),
                const SizedBox(width: 8),
                Text(file.priority == FilePriority.HIGH ? 'Обычный приоритет' : 'Высокий приоритет'),
              ],
            ),
          ),
        ],
      ),
      onTap: isVideo && file.progress >= 0.1 
          ? () => _playVideo(file, 'native')
          : null,
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  void _handleAction(String action) async {
    final provider = context.read<DownloadsProvider>();
    
    switch (action) {
      case 'pause':
        await provider.pauseTorrent(widget.infoHash);
        _loadTorrentInfo();
        break;
      case 'resume':
        await provider.resumeTorrent(widget.infoHash);
        _loadTorrentInfo();
        break;
      case 'refresh':
        _loadTorrentInfo();
        break;
      case 'remove':
        _showRemoveConfirmation();
        break;
    }
  }

  void _handleFileAction(String action, TorrentFileInfo file) async {
    final provider = context.read<DownloadsProvider>();
    
    if (action.startsWith('play_')) {
      final playerType = action.replaceFirst('play_', '');
      _playVideo(file, playerType);
      return;
    }
    
    if (action.startsWith('priority_')) {
      final priority = action.replaceFirst('priority_', '');
      final newPriority = priority == 'high' ? FilePriority.HIGH : FilePriority.NORMAL;
      
      final fileIndex = torrentInfo!.files.indexOf(file);
      await provider.setFilePriority(widget.infoHash, fileIndex, newPriority);
      _loadTorrentInfo();
      return;
    }
    
    switch (action) {
      case 'download':
        final fileIndex = torrentInfo!.files.indexOf(file);
        await provider.setFilePriority(widget.infoHash, fileIndex, FilePriority.NORMAL);
        _loadTorrentInfo();
        break;
      case 'stop_download':
        final fileIndex = torrentInfo!.files.indexOf(file);
        await provider.setFilePriority(widget.infoHash, fileIndex, FilePriority.DONT_DOWNLOAD);
        _loadTorrentInfo();
        break;
    }
  }

  void _playVideo(TorrentFileInfo file, String playerType) {
    final filePath = '${torrentInfo!.savePath}/${file.path}';
    
    switch (playerType) {
      case 'native':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              filePath: filePath,
              title: file.path.split('/').last,
            ),
          ),
        );
        break;
      case 'vibix':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewPlayerScreen(
              playerType: WebPlayerType.vibix,
              videoUrl: filePath,
              title: file.path.split('/').last,
            ),
          ),
        );
        break;
      case 'alloha':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewPlayerScreen(
              playerType: WebPlayerType.alloha,
              videoUrl: filePath,
              title: file.path.split('/').last,
            ),
          ),
        );
        break;
    }
  }

  void _showRemoveConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Удалить торрент'),
          content: Text(
            'Вы уверены, что хотите удалить "${torrentInfo!.name}"?\n\nФайлы будут удалены с устройства.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<DownloadsProvider>().removeTorrent(widget.infoHash);
                Navigator.of(context).pop(); // Возвращаемся к списку загрузок
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );
  }
}