import 'package:flutter/material.dart';
import 'package:neomovies_mobile/data/models/movie.dart';
import 'package:neomovies_mobile/data/repositories/movie_repository.dart';

class SearchProvider extends ChangeNotifier {
  final MovieRepository _repository;
  SearchProvider(this._repository);

  List<Movie> _results = [];
  List<Movie> get results => _results;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _results = await _repository.searchMovies(query);
      _results.sort((a, b) => b.popularity.compareTo(a.popularity));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _results = [];
    _error = null;
    notifyListeners();
  }
}
