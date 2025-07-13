import 'package:neomovies_mobile/data/api/api_client.dart';
import 'package:neomovies_mobile/data/models/movie.dart';
import 'package:neomovies_mobile/data/models/movie_preview.dart';

class MovieRepository {
  final ApiClient _apiClient;

  MovieRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<Movie>> getPopularMovies({int page = 1}) async {
    return _apiClient.getPopularMovies(page: page);
  }

  Future<List<Movie>> getTopRatedMovies({int page = 1}) async {
    return _apiClient.getTopRatedMovies(page: page);
  }

  Future<List<Movie>> getUpcomingMovies({int page = 1}) async {
    return _apiClient.getUpcomingMovies(page: page);
  }

  Future<Movie> getMovieById(String movieId) async {
    return _apiClient.getMovieById(movieId);
  }

  Future<Movie> getTvById(String tvId) async {
    return _apiClient.getTvById(tvId);
  }

  Future<List<Movie>> searchMovies(String query, {int page = 1}) async {
    return _apiClient.searchMovies(query, page: page);
  }
}
