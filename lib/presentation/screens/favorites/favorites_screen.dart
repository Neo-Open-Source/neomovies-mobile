import 'package:flutter/material.dart';
import 'package:neomovies_mobile/presentation/providers/auth_provider.dart';
import 'package:neomovies_mobile/presentation/providers/favorites_provider.dart';
import 'package:neomovies_mobile/presentation/screens/auth/login_screen.dart';
import 'package:neomovies_mobile/presentation/widgets/movie_grid_item.dart';
import 'package:neomovies_mobile/utils/device_utils.dart';
import 'package:provider/provider.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isAuthenticated) {
      return _buildLoggedOutView(context);
    } else {
      return _buildLoggedInView(context);
    }
  }

  Widget _buildLoggedOutView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Login to see your favorites',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Save movies and TV shows to keep them.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ));
              },
              child: const Text('Login to your account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedInView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
      body: Consumer<FavoritesProvider>(
        builder: (context, favoritesProvider, child) {
          if (favoritesProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (favoritesProvider.error != null) {
            return Center(child: Text('Error: ${favoritesProvider.error}'));
          }

          if (favoritesProvider.favorites.isEmpty) {
            return _buildEmptyFavoritesView(context);
          }

          final gridCount = DeviceUtils.calculateGridCount(context);
          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridCount,
              childAspectRatio: 0.56,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: favoritesProvider.favorites.length,
            itemBuilder: (context, index) {
              final favorite = favoritesProvider.favorites[index];
              return MovieGridItem(favorite: favorite);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyFavoritesView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_filter_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Favorites are empty',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add movies by tapping on the heart.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
