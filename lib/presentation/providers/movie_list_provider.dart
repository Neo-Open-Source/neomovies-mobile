import 'package:flutter/material.dart';
import 'package:neomovies_mobile/data/models/movie.dart';
import 'package:neomovies_mobile/data/repositories/movie_repository.dart';

// Enum to define the category of movies to fetch
enum MovieCategory { popular, topRated, upcoming }

class MovieListProvider extends ChangeNotifier {
  final MovieRepository _movieRepository;
  final MovieCategory category;

  MovieListProvider({
    required this.category,
    required MovieRepository movieRepository,
  }) : _movieRepository = movieRepository;

  List<Movie> _movies = [];
  List<Movie> get movies => _movies;

  int _currentPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;

  Future<void> fetchInitialMovies() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newMovies = await _fetchMoviesForCategory(page: 1);
      _movies = newMovies;
      _currentPage = 1;
      _hasMore = newMovies.isNotEmpty;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchNextPage() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final newMovies = await _fetchMoviesForCategory(page: _currentPage + 1);
      _movies.addAll(newMovies);
      _currentPage++;
      _hasMore = newMovies.isNotEmpty;
    } catch (e) {
      // Optionally handle error for pagination differently
      _errorMessage = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<List<Movie>> _fetchMoviesForCategory({required int page}) {
    switch (category) {
      case MovieCategory.popular:
        return _movieRepository.getPopularMovies(page: page);
      case MovieCategory.topRated:
        return _movieRepository.getTopRatedMovies(page: page);
      case MovieCategory.upcoming:
        return _movieRepository.getUpcomingMovies(page: page);
    }
  }

  String getTitle() {
    switch (category) {
      case MovieCategory.popular:
        return 'Popular Movies';
      case MovieCategory.topRated:
        return 'Top Rated Movies';
      case MovieCategory.upcoming:
        return 'Latest Movies';
    }
  }
}
