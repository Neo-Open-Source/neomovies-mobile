import 'package:flutter/material.dart';
import 'package:neomovies_mobile/data/models/movie.dart';
import 'package:neomovies_mobile/data/repositories/movie_repository.dart';

enum ViewState { idle, loading, success, error }

class HomeProvider extends ChangeNotifier {
  final MovieRepository _movieRepository;

  HomeProvider({required MovieRepository movieRepository})
      : _movieRepository = movieRepository;

  List<Movie> _popularMovies = [];
  List<Movie> get popularMovies => _popularMovies;

  List<Movie> _topRatedMovies = [];
  List<Movie> get topRatedMovies => _topRatedMovies;

  List<Movie> _upcomingMovies = [];
  List<Movie> get upcomingMovies => _upcomingMovies;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Initial fetch
  void init() {
    fetchAllMovies();
  }

  Future<void> fetchAllMovies() async {
    _isLoading = true;
    _errorMessage = null;
    // Notify listeners only for the initial loading state
    if (_popularMovies.isEmpty) {
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _movieRepository.getPopularMovies(),
        _movieRepository.getTopRatedMovies(),
        _movieRepository.getUpcomingMovies(),
      ]);

      _popularMovies = results[0];
      _topRatedMovies = results[1];
      _upcomingMovies = results[2];

    } catch (e) {
      _errorMessage = 'Failed to fetch movies: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
