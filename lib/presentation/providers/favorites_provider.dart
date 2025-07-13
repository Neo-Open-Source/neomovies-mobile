import 'package:flutter/material.dart';
import 'package:neomovies_mobile/data/models/favorite.dart';
import 'package:neomovies_mobile/data/models/movie.dart';
import 'package:neomovies_mobile/data/repositories/favorites_repository.dart';
import 'package:neomovies_mobile/presentation/providers/auth_provider.dart';

class FavoritesProvider extends ChangeNotifier {
  final FavoritesRepository _favoritesRepository;
  AuthProvider _authProvider;

  List<Favorite> _favorites = [];
  bool _isLoading = false;
  String? _error;

  List<Favorite> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get error => _error;

  FavoritesProvider(this._favoritesRepository, this._authProvider) {
    // Listen for authentication state changes
    _authProvider.addListener(_onAuthStateChanged);
    _onAuthStateChanged();
  }

  void update(AuthProvider authProvider) {
    // Remove listener from previous AuthProvider to avoid leaks
    _authProvider.removeListener(_onAuthStateChanged);
    _authProvider = authProvider;
    _authProvider.addListener(_onAuthStateChanged);
    _onAuthStateChanged();
  }

  void _onAuthStateChanged() {
    if (_authProvider.isAuthenticated) {
      fetchFavorites();
    } else {
      _clearFavorites();
    }
  }

  Future<void> fetchFavorites() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _favorites = await _favoritesRepository.getFavorites();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addFavorite(Movie movie) async {
    try {
      await _favoritesRepository.addFavorite(
        movie.id.toString(),
        'movie', // Assuming mediaType is 'movie'
        movie.title,
        movie.posterPath ?? '',
      );
      await fetchFavorites(); // Refresh the list
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeFavorite(String mediaId) async {
    try {
      await _favoritesRepository.removeFavorite(mediaId);
      _favorites.removeWhere((fav) => fav.mediaId == mediaId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  bool isFavorite(String mediaId) {
    return _favorites.any((fav) => fav.mediaId == mediaId);
  }

  void _clearFavorites() {
    _favorites = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }


}
