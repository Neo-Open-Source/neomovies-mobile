import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/downloads_provider.dart';
import '../../widgets/error_display.dart';
import '../../../data/models/torrent_info.dart';
import 'torrent_detail_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DownloadsProvider>().refreshDownloads();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Загрузки'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<DownloadsProvider>().refreshDownloads();
            },
          ),
        ],
      ),
      body: Consumer<DownloadsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.error != null) {
            return ErrorDisplay(
              title: 'Ошибка загрузки торрентов',
              error: provider.error!,
              stackTrace: provider.stackTrace,
              onRetry: () {
                provider.refreshDownloads();
              },
            );
          }

          if (provider.torrents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.download_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет активных загрузок',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Загруженные торренты будут отображаться здесь',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.refreshDownloads();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.torrents.length,
              itemBuilder: (context, index) {
                final torrent = provider.torrents[index];
                return TorrentListItem(
                  torrent: torrent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TorrentDetailScreen(
                          infoHash: torrent.infoHash,
                        ),
                      ),
                    );
                  },
                  onMenuPressed: (action) {
                    _handleTorrentAction(action, torrent);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _handleTorrentAction(TorrentAction action, TorrentInfo torrent) {
    final provider = context.read<DownloadsProvider>();
    
    switch (action) {
      case TorrentAction.pause:
        provider.pauseTorrent(torrent.infoHash);
        break;
      case TorrentAction.resume:
        provider.resumeTorrent(torrent.infoHash);
        break;
      case TorrentAction.remove:
        _showRemoveConfirmation(torrent);
        break;
      case TorrentAction.openFolder:
        _openFolder(torrent);
        break;
    }
  }

  void _showRemoveConfirmation(TorrentInfo torrent) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Удалить торрент'),
          content: Text(
            'Вы уверены, что хотите удалить "${torrent.name}"?\n\nФайлы будут удалены с устройства.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<DownloadsProvider>().removeTorrent(torrent.infoHash);
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

  void _openFolder(TorrentInfo torrent) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Папка: ${torrent.savePath}'),
        action: SnackBarAction(
          label: 'Копировать',
          onPressed: () {
            // TODO: Copy path to clipboard
          },
        ),
      ),
    );
  }
}

enum TorrentAction { pause, resume, remove, openFolder }

class TorrentListItem extends StatelessWidget {
  final TorrentInfo torrent;
  final VoidCallback onTap;
  final Function(TorrentAction) onMenuPressed;

  const TorrentListItem({
    super.key,
    required this.torrent,
    required this.onTap,
    required this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      torrent.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<TorrentAction>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: onMenuPressed,
                    itemBuilder: (BuildContext context) => [
                      if (torrent.isPaused)
                        const PopupMenuItem(
                          value: TorrentAction.resume,
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
                          value: TorrentAction.pause,
                          child: Row(
                            children: [
                              Icon(Icons.pause),
                              SizedBox(width: 8),
                              Text('Приостановить'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: TorrentAction.openFolder,
                        child: Row(
                          children: [
                            Icon(Icons.folder_open),
                            SizedBox(width: 8),
                            Text('Открыть папку'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: TorrentAction.remove,
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
              const SizedBox(height: 12),
              _buildProgressBar(context),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatusChip(),
                  const Spacer(),
                  Text(
                    torrent.formattedTotalSize,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              if (torrent.isDownloading || torrent.isSeeding) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.download,
                      size: 16,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      torrent.formattedDownloadSpeed,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.upload,
                      size: 16,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      torrent.formattedUploadSpeed,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      'S: ${torrent.numSeeds} P: ${torrent.numPeers}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Прогресс',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              '${(torrent.progress * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
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
    );
  }

  Widget _buildStatusChip() {
    Color color;
    IconData icon;
    String text;

    if (torrent.isCompleted) {
      color = Colors.green;
      icon = Icons.check_circle;
      text = 'Завершен';
    } else if (torrent.isDownloading) {
      color = Colors.blue;
      icon = Icons.download;
      text = 'Загружается';
    } else if (torrent.isPaused) {
      color = Colors.orange;
      icon = Icons.pause;
      text = 'Приостановлен';
    } else if (torrent.isSeeding) {
      color = Colors.purple;
      icon = Icons.upload;
      text = 'Раздача';
    } else {
      color = Colors.grey;
      icon = Icons.help_outline;
      text = torrent.state;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}