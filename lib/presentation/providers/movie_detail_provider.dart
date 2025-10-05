import 'package:flutter/material.dart';
import 'package:neomovies_mobile/data/models/movie.dart';
import 'package:neomovies_mobile/data/repositories/movie_repository.dart';
import 'package:neomovies_mobile/data/api/api_client.dart';

class MovieDetailProvider with ChangeNotifier {
  final MovieRepository _movieRepository;
  final ApiClient _apiClient;

  MovieDetailProvider(this._movieRepository, this._apiClient);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isImdbLoading = false;
  bool get isImdbLoading => _isImdbLoading;

  Movie? _movie;
  Movie? get movie => _movie;

  String? _imdbId;
  String? get imdbId => _imdbId;

  String? _error;
  String? get error => _error;

  Future<void> loadMedia(int mediaId, String mediaType) async {
    _isLoading = true;
    _isImdbLoading = true;
    _error = null;
    _movie = null;
    _imdbId = null;
    notifyListeners();

    try {
      print('Loading media: ID=$mediaId, type=$mediaType');
      
      // Load movie/TV details
      if (mediaType == 'movie') {
        _movie = await _movieRepository.getMovieById(mediaId.toString());
        print('Movie loaded successfully: ${_movie?.title}');
      } else {
        _movie = await _movieRepository.getTvById(mediaId.toString());
        print('TV show loaded successfully: ${_movie?.title}');
      }
      
      _isLoading = false;
      notifyListeners();

      // Try to load IMDb ID (non-blocking)
      if (_movie != null) {
        try {
          print('Loading IMDb ID for $mediaType $mediaId');
          _imdbId = await _apiClient.getImdbId(mediaId.toString(), mediaType);
          print('IMDb ID loaded: $_imdbId');
        } catch (e) {
          // IMDb ID loading failed, but don't fail the whole screen
          print('Failed to load IMDb ID: $e');
          _imdbId = null;
        }
      }
    } catch (e, stackTrace) {
      print('Error loading media: $e');
      print('Stack trace: $stackTrace');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    } finally {
      _isImdbLoading = false;
      notifyListeners();
    }
  }

  // Backward compatibility
  Future<void> loadMovie(int movieId) async {
    await loadMedia(movieId, 'movie');
  }
}
