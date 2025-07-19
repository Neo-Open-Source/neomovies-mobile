import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/torrent.dart';
import '../../../data/services/torrent_service.dart';
import '../../cubits/torrent/torrent_cubit.dart';
import '../../cubits/torrent/torrent_state.dart';
import '../torrent_file_selector/torrent_file_selector_screen.dart';

class TorrentSelectorScreen extends StatefulWidget {
  final String imdbId;
  final String mediaType;
  final String title;

  const TorrentSelectorScreen({
    super.key,
    required this.imdbId,
    required this.mediaType,
    required this.title,
  });

  @override
  State<TorrentSelectorScreen> createState() => _TorrentSelectorScreenState();
}

class _TorrentSelectorScreenState extends State<TorrentSelectorScreen> {
  String? _selectedMagnet;
  bool _isCopied = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TorrentCubit(torrentService: TorrentService())
        ..loadTorrents(
          imdbId: widget.imdbId,
          mediaType: widget.mediaType,
        ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Выбор для загрузки'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        body: Column(
          children: [
            // Header with movie info
            _buildMovieHeader(context),
            
            // Content
            Expanded(
              child: BlocBuilder<TorrentCubit, TorrentState>(
                builder: (context, state) {
                  return state.when(
                    initial: () => const SizedBox.shrink(),
                    loading: () => const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Загрузка торрентов...'),
                        ],
                      ),
                    ),
                    loaded: (torrents, qualityGroups, imdbId, mediaType, selectedSeason, availableSeasons, selectedQuality) =>
                        _buildLoadedContent(
                      context,
                      torrents,
                      qualityGroups,
                      mediaType,
                      selectedSeason,
                      availableSeasons,
                      selectedQuality,
                    ),
                    error: (message) => _buildErrorContent(context, message),
                  );
                },
              ),
            ),
            
            // Selected magnet section
            if (_selectedMagnet != null) _buildSelectedMagnetSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieHeader(BuildContext context) {
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
      child: Row(
        children: [
          Icon(
            widget.mediaType == 'tv' ? Icons.tv : Icons.movie,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.mediaType == 'tv' ? 'Сериал' : 'Фильм',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedContent(
    BuildContext context,
    List<Torrent> torrents,
    Map<String, List<Torrent>> qualityGroups,
    String mediaType,
    int? selectedSeason,
    List<int>? availableSeasons,
    String? selectedQuality,
  ) {
    return Column(
      children: [
        // Season selector for TV shows
        if (mediaType == 'tv' && availableSeasons != null && availableSeasons.isNotEmpty)
          _buildSeasonSelector(context, availableSeasons, selectedSeason),
        
        // Quality selector
        if (qualityGroups.isNotEmpty)
          _buildQualitySelector(context, qualityGroups, selectedQuality),
        
        // Torrents list
        Expanded(
          child: torrents.isEmpty
              ? _buildEmptyState(context)
              : _buildTorrentsGroupedList(context, qualityGroups, selectedQuality),
        ),
      ],
    );
  }

  Widget _buildSeasonSelector(BuildContext context, List<int> seasons, int? selectedSeason) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сезон',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: seasons.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final season = seasons[index];
                final isSelected = season == selectedSeason;
                return FilterChip(
                  label: Text('Сезон $season'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      context.read<TorrentCubit>().selectSeason(season);
                      setState(() {
                        _selectedMagnet = null;
                        _isCopied = false;
                      });
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualitySelector(BuildContext context, Map<String, List<Torrent>> qualityGroups, String? selectedQuality) {
    final qualities = qualityGroups.keys.toList();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Качество',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: qualities.length + 1, // +1 для кнопки "Все"
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Кнопка "Все"
                  return FilterChip(
                    label: const Text('Все'),
                    selected: selectedQuality == null,
                    onSelected: (selected) {
                      if (selected) {
                        context.read<TorrentCubit>().selectQuality(null);
                      }
                    },
                  );
                }
                
                final quality = qualities[index - 1];
                final count = qualityGroups[quality]?.length ?? 0;
                return FilterChip(
                  label: Text('$quality ($count)'),
                  selected: quality == selectedQuality,
                  onSelected: (selected) {
                    if (selected) {
                      context.read<TorrentCubit>().selectQuality(quality);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTorrentsGroupedList(BuildContext context, Map<String, List<Torrent>> qualityGroups, String? selectedQuality) {
    // Если выбрано конкретное качество, показываем только его
    if (selectedQuality != null) {
      final torrents = qualityGroups[selectedQuality] ?? [];
      if (torrents.isEmpty) {
        return _buildEmptyState(context);
      }
      return _buildTorrentsList(context, torrents);
    }
    
    // Иначе показываем все группы
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: qualityGroups.length,
      itemBuilder: (context, index) {
        final quality = qualityGroups.keys.elementAt(index);
        final torrents = qualityGroups[quality]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок группы качества
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      quality,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${torrents.length} раздач',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Список торрентов в группе
            ...torrents.map((torrent) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTorrentItem(context, torrent),
            )).toList(),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildTorrentsList(BuildContext context, List<Torrent> torrents) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: torrents.length,
      itemBuilder: (context, index) {
        final torrent = torrents[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTorrentItem(context, torrent),
        );
      },
    );
  }

  Widget _buildTorrentItem(BuildContext context, Torrent torrent) {
    final title = torrent.title ?? torrent.name ?? 'Неизвестная раздача';
    final quality = torrent.quality;
    final seeders = torrent.seeders;
    final isSelected = _selectedMagnet == torrent.magnet;

    return Card(
      elevation: isSelected ? 4 : 1,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMagnet = torrent.magnet;
            _isCopied = false;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected 
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (quality != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        quality,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (seeders != null) ...[
                    Icon(
                      Icons.upload,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$seeders',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (torrent.size != null) ...[
                    Icon(
                      Icons.storage,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatFileSize(torrent.size),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              if (isSelected) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Выбрано',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Торренты не найдены',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Попробуйте выбрать другой сезон',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                    text: 'Ошибка загрузки\n',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextSpan(
                    text: message,
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
              onPressed: () {
                context.read<TorrentCubit>().loadTorrents(
                  imdbId: widget.imdbId,
                  mediaType: widget.mediaType,
                );
              },
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedMagnetSection(BuildContext context) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Magnet-ссылка',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                ),
              ),
              child: Text(
                _selectedMagnet!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: Icon(_isCopied ? Icons.check : Icons.copy, size: 20),
                    label: Text(_isCopied ? 'Скопировано!' : 'Копировать'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openFileSelector,
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text('Скачать'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int? sizeInBytes) {
    if (sizeInBytes == null || sizeInBytes == 0) return 'Неизвестно';
    
    const int kb = 1024;
    const int mb = kb * 1024;
    const int gb = mb * 1024;
    
    if (sizeInBytes >= gb) {
      return '${(sizeInBytes / gb).toStringAsFixed(1)} GB';
    } else if (sizeInBytes >= mb) {
      return '${(sizeInBytes / mb).toStringAsFixed(0)} MB';
    } else if (sizeInBytes >= kb) {
      return '${(sizeInBytes / kb).toStringAsFixed(0)} KB';
    } else {
      return '$sizeInBytes B';
    }
  }

  void _openFileSelector() {
    if (_selectedMagnet != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TorrentFileSelectorScreen(
            magnetLink: _selectedMagnet!,
            torrentTitle: widget.title,
          ),
        ),
      );
    }
  }

  void _copyToClipboard() {
    if (_selectedMagnet != null) {
      Clipboard.setData(ClipboardData(text: _selectedMagnet!));
      setState(() {
        _isCopied = true;
      });
      
      // Показываем снэкбар
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Magnet-ссылка скопирована в буфер обмена'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Сбрасываем состояние через 2 секунды
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isCopied = false;
          });
        }
      });
    }
  }
}
