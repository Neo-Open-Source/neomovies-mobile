import 'package:flutter/material.dart';
import 'package:neomovies_mobile/data/models/movie.dart';
import 'package:neomovies_mobile/presentation/providers/home_provider.dart';
import 'package:neomovies_mobile/presentation/providers/movie_list_provider.dart';
import 'package:neomovies_mobile/presentation/screens/movie_list_screen.dart';
import 'package:neomovies_mobile/presentation/widgets/movie_card.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to settings screen
            },
          ),
        ],
      ),
      body: Consumer<HomeProvider>(
        builder: (context, provider, child) {
          // Показываем загрузку только при первом запуске
          if (provider.isLoading && provider.popularMovies.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Показываем ошибку, если она есть
          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(provider.errorMessage!, textAlign: TextAlign.center),
              ),
            );
          }

          // Основной контент с возможностью "потянуть для обновления"
          return RefreshIndicator(
            onRefresh: provider.fetchAllMovies,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              children: [
                if (provider.popularMovies.isNotEmpty)
                  _MovieCarousel(
                    title: 'Popular Movies',
                    movies: provider.popularMovies,
                    category: MovieCategory.popular,
                  ),
                if (provider.upcomingMovies.isNotEmpty)
                  _MovieCarousel(
                    title: 'Latest Movies',
                    movies: provider.upcomingMovies,
                    category: MovieCategory.upcoming,
                  ),
                if (provider.topRatedMovies.isNotEmpty)
                  _MovieCarousel(
                    title: 'Top Rated Movies',
                    movies: provider.topRatedMovies,
                    category: MovieCategory.topRated,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Вспомогательный виджет для карусели фильмов
class _MovieCarousel extends StatelessWidget {
  final String title;
  final List<Movie> movies;
  final MovieCategory category;

  const _MovieCarousel({
    required this.title,
    required this.movies,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 280, // Maintained height for movie cards
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            // Add one more item for the 'More' button
            itemCount: movies.length + 1,
            itemBuilder: (context, index) {
              // If it's the last item, show the 'More' button
              if (index == movies.length) {
                return _buildMoreButton(context);
              }

              final movie = movies[index];
              return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 2.0 : 2.0,
                ),
                child: MovieCard(movie: movie),
              );
            },
          ),
        ),
        const SizedBox(height: 16), // Further reduced bottom padding
      ],
    );
  }

  // A new widget for the 'More' button
  Widget _buildMoreButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: 150, // Same width as MovieCard
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MovieListScreen(category: category),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.arrow_forward_ios_rounded, size: 40),
              const SizedBox(height: 8),
              Text(
                'More',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}