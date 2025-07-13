import 'package:flutter/material.dart';
import 'package:neomovies_mobile/data/repositories/movie_repository.dart';
import 'package:neomovies_mobile/presentation/providers/movie_list_provider.dart';
import 'package:neomovies_mobile/presentation/widgets/movie_card.dart';
import 'package:provider/provider.dart';
import '../../utils/device_utils.dart';

class MovieListScreen extends StatelessWidget {
  final MovieCategory category;

  const MovieListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MovieListProvider(
        category: category,
        movieRepository: context.read<MovieRepository>(),
      )..fetchInitialMovies(),
      child: const _MovieListScreenContent(),
    );
  }
}

class _MovieListScreenContent extends StatefulWidget {
  const _MovieListScreenContent();

  @override
  State<_MovieListScreenContent> createState() => _MovieListScreenContentState();
}

class _MovieListScreenContentState extends State<_MovieListScreenContent> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<MovieListProvider>().fetchNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieListProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.getTitle()),
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(MovieListProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.movies.isEmpty) {
      return Center(child: Text('Error: ${provider.errorMessage}'));
    }

    if (provider.movies.isEmpty) {
      return const Center(child: Text('No movies found.'));
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: DeviceUtils.calculateGridCount(context),
        childAspectRatio: 0.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: provider.movies.length + (provider.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= provider.movies.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final movie = provider.movies[index];
        return MovieCard(movie: movie);
      },
    );
  }
}
