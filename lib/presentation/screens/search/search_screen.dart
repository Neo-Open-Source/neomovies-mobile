import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:neomovies_mobile/presentation/providers/search_provider.dart';
import 'package:neomovies_mobile/presentation/widgets/movie_card.dart';
import 'package:neomovies_mobile/data/repositories/movie_repository.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SearchProvider(context.read<MovieRepository>()),
      child: const _SearchContent(),
    );
  }
}

class _SearchContent extends StatefulWidget {
  const _SearchContent();

  @override
  State<_SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<_SearchContent> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSubmitted(String query) {
    context.read<SearchProvider>().search(query);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SearchProvider>();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: _onSubmitted,
          decoration: const InputDecoration(
            hintText: 'Search movies or TV shows',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _controller.clear();
              provider.clear();
            },
          ),
        ],
      ),
      body: () {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.error != null) {
          return Center(child: Text('Error: ${provider.error}'));
        }
        if (provider.results.isEmpty) {
          return const Center(child: Text('No results'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.6,
          ),
          itemCount: provider.results.length,
          itemBuilder: (context, index) {
            final movie = provider.results[index];
            return MovieCard(movie: movie);
          },
        );
      }(),
    );
  }
}
