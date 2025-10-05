import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:neomovies_mobile/presentation/providers/auth_provider.dart';
import 'package:neomovies_mobile/presentation/providers/favorites_provider.dart';
import 'package:neomovies_mobile/presentation/providers/reactions_provider.dart';
import 'package:neomovies_mobile/presentation/providers/movie_detail_provider.dart';
import 'package:neomovies_mobile/presentation/screens/player/video_player_screen.dart';
import 'package:neomovies_mobile/presentation/screens/torrent_selector/torrent_selector_screen.dart';
import 'package:neomovies_mobile/presentation/widgets/error_display.dart';
import 'package:provider/provider.dart';

class MovieDetailScreen extends StatefulWidget {
  final String movieId;
  final String mediaType;

  const MovieDetailScreen({super.key, required this.movieId, this.mediaType = 'movie'});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load movie details and reactions
      Provider.of<MovieDetailProvider>(context, listen: false).loadMedia(int.parse(widget.movieId), widget.mediaType);
      Provider.of<ReactionsProvider>(context, listen: false).loadReactionsForMedia(widget.mediaType, widget.movieId);
    });
  }

  void _openTorrentSelector(BuildContext context, String? imdbId, String title) {
    if (imdbId == null || imdbId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('IMDB ID не найден. Невозможно загрузить торренты.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TorrentSelectorScreen(
          imdbId: imdbId,
          mediaType: widget.mediaType,
          title: title,
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context, String? imdbId, String title) {
    if (imdbId == null || imdbId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('IMDB ID not found. Cannot open player.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // TODO: Implement proper player navigation with mediaId
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Player feature will be implemented. Media ID: $imdbId'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Consumer<MovieDetailProvider>(
          builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return ErrorDisplay(
              title: 'Ошибка загрузки ${widget.mediaType == 'movie' ? 'фильма' : 'сериала'}',
              error: provider.error!,
              stackTrace: provider.stackTrace,
              onRetry: () {
                Provider.of<MovieDetailProvider>(context, listen: false)
                    .loadMedia(int.parse(widget.movieId), widget.mediaType);
              },
            );
          }

          if (provider.movie == null) {
            return const Center(child: Text('Movie not found'));
          }

          final movie = provider.movie!;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: movie.fullPosterUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  movie.title,
                  style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),

                // Tagline
                if (movie.tagline != null && movie.tagline!.isNotEmpty)
                  Text(
                    movie.tagline!,
                    style: textTheme.titleMedium?.copyWith(color: textTheme.bodySmall?.color),
                  ),
                const SizedBox(height: 16),

                // Meta Info
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Рейтинг: ${movie.voteAverage?.toStringAsFixed(1) ?? 'N/A'}'),
                    const Text('|'),
                    if (movie.mediaType == 'tv')
                      Text('${movie.seasonsCount ?? '-'} сез., ${movie.episodesCount ?? '-'} сер.')
                    else if (movie.runtime != null)
                      Text('${movie.runtime} мин.'),
                    const Text('|'),
                    if (movie.releaseDate != null)
                      Text(DateFormat('d MMMM yyyy', 'ru').format(movie.releaseDate!)),
                  ],
                ),
                const SizedBox(height: 16),

                // Genres
                if (movie.genres != null && movie.genres!.isNotEmpty)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: movie.genres!
                        .map((genre) => Chip(
                              label: Text(genre),
                              backgroundColor: colorScheme.secondaryContainer,
                              labelStyle: textTheme.bodySmall?.copyWith(color: colorScheme.onSecondaryContainer),
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 24),

                // Reactions Section
                _buildReactionsSection(context),
                const SizedBox(height: 24),

                // Overview
                Text(
                  'Описание',
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  movie.overview ?? 'Описание недоступно.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: Consumer<MovieDetailProvider>(
                        builder: (context, provider, child) {
                          final imdbId = provider.imdbId;
                          final isImdbLoading = provider.isImdbLoading;

                          return ElevatedButton.icon(
                            onPressed: (isImdbLoading || imdbId == null)
                                ? null // Делаем кнопку неактивной во время загрузки или если нет ID
                                : () {
                                    _openPlayer(context, imdbId, provider.movie!.title);
                                  },
                            icon: isImdbLoading
                                ? Container(
                                    width: 24,
                                    height: 24,
                                    padding: const EdgeInsets.all(2.0),
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Icon(Icons.play_arrow),
                            label: const Text('Смотреть'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ).copyWith(
                              // Устанавливаем цвет для неактивного состояния
                              backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                                (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.disabled)) {
                                    return Colors.grey;
                                  }
                                  return Theme.of(context).colorScheme.primary;
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Consumer<FavoritesProvider>(
                      builder: (context, favoritesProvider, child) {
                        final isFavorite = favoritesProvider.isFavorite(widget.movieId);
                        return IconButton(
                          onPressed: () {
                            final authProvider = context.read<AuthProvider>();
                            if (!authProvider.isAuthenticated) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Войдите в аккаунт, чтобы добавлять в избранное.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }

                            if (isFavorite) {
                              favoritesProvider.removeFavorite(widget.movieId);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Удалено из избранного'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } else {
                              favoritesProvider.addFavorite(movie);
                               ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Добавлено в избранное'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor: isFavorite ? Colors.red.withOpacity(0.1) : colorScheme.secondaryContainer,
                            foregroundColor: isFavorite ? Colors.red : colorScheme.onSecondaryContainer,
                          ),
                        );
                      },
                    ),
                    // Download button
                    const SizedBox(width: 12),
                    Consumer<MovieDetailProvider>(
                      builder: (context, provider, child) {
                        final imdbId = provider.imdbId;
                        final isImdbLoading = provider.isImdbLoading;
                        
                        return IconButton(
                          onPressed: (isImdbLoading || imdbId == null)
                              ? null
                              : () => _openTorrentSelector(context, imdbId, movie.title),
                          icon: isImdbLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download),
                          iconSize: 28,
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.primaryContainer,
                            foregroundColor: colorScheme.onPrimaryContainer,
                          ),
                          tooltip: 'Скачать торрент',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        ),
    );
  }

  Widget _buildReactionsSection(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Define the reactions with their icons and backend types
    // Map of UI reaction types to backend types and icons
    final List<Map<String, dynamic>> reactions = [
      {'uiType': 'like', 'backendType': 'fire', 'icon': Icons.local_fire_department},
      {'uiType': 'nice', 'backendType': 'nice', 'icon': Icons.thumb_up_alt},
      {'uiType': 'think', 'backendType': 'think', 'icon': Icons.psychology},
      {'uiType': 'bore', 'backendType': 'bore', 'icon': Icons.sentiment_dissatisfied},
      {'uiType': 'shit', 'backendType': 'shit', 'icon': Icons.thumb_down_alt},
    ];

    return Consumer<ReactionsProvider>(
      builder: (context, provider, child) {
        // Debug: Print current reaction data
        // print('REACTIONS DEBUG:');
        // print('- User reaction: ${provider.userReaction}');
        // print('- Reaction counts: ${provider.reactionCounts}');
        
        if (provider.isLoading && provider.reactionCounts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(child: Text('Error loading reactions: ${provider.error}'));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Реакции',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: reactions.map((reaction) {
                final uiType = reaction['uiType'] as String;
                final backendType = reaction['backendType'] as String;
                final icon = reaction['icon'] as IconData;
                final count = provider.reactionCounts[backendType] ?? 0;
                final isSelected = provider.userReaction == backendType;

                return Column(
                  children: [
                    IconButton(
                      icon: Icon(icon),
                      iconSize: 28,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      onPressed: () {
                        if (!authProvider.isAuthenticated) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Login to your account to leave a reaction.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        provider.setReaction(widget.mediaType, widget.movieId, backendType);
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count.toString(), 
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
