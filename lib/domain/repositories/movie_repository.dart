import 'package:hive_flutter/hive_flutter.dart';
import 'package:neomovies_mobile/data/api/api_client.dart';
import 'package:neomovies_mobile/data/models/movie.dart';
import 'package:neomovies_mobile/data/models/movie_preview.dart';

class MovieRepository {
  final ApiClient _apiClient;

  static const String popularBox = 'popularMovies';
  static const String topRatedBox = 'topRatedMovies';
  static const String upcomingBox = 'upcomingMovies';

  MovieRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<Movie>> getPopularMovies({int page = 1}) async {
    return _getCachedThenFetch(
      boxName: popularBox,
      fetch: () => _apiClient.getPopularMovies(page: page),
      page: page,
    );
  }

  Future<List<Movie>> getTopRatedMovies({int page = 1}) async {
    return _getCachedThenFetch(
      boxName: topRatedBox,
      fetch: () => _apiClient.getTopRatedMovies(page: page),
      page: page,
    );
  }

  Future<List<Movie>> getUpcomingMovies({int page = 1}) async {
    return _getCachedThenFetch(
      boxName: upcomingBox,
      fetch: () => _apiClient.getUpcomingMovies(page: page),
      page: page,
    );
  }

  Future<Movie> getMovieDetails(String id) async {
    // Caching for movie details can be added later if needed.
    return _apiClient.getMovieById(id);
  }

  Future<List<Movie>> _getCachedThenFetch({
    required String boxName,
    required Future<List<Movie>> Function() fetch,
    required int page,
  }) async {
    final box = await Hive.openBox<MoviePreview>(boxName);

    if (page == 1 && box.isNotEmpty) {
      final cachedPreviews = box.values.toList();
      // Convert cached previews to full Movie objects for the UI
      final cachedMovies = cachedPreviews
          .map((p) => Movie(id: p.id, title: p.title, posterPath: p.posterPath))
          .toList();

      // Fetch new data in the background but don't wait for it here
      _fetchAndCache(box, fetch, page);
      return cachedMovies;
    }

    // If no cache or not the first page, fetch from network
    final networkMovies = await _fetchAndCache(box, fetch, page);
    return networkMovies;
  }

  Future<List<Movie>> _fetchAndCache(
    Box<MoviePreview> box,
    Future<List<Movie>> Function() fetch,
    int page,
  ) async {
    try {
      final networkMovies = await fetch();
      if (page == 1) {
        await box.clear();
        for (var movie in networkMovies) {
          // Save the lightweight preview version to the cache
          final preview = MoviePreview(
            id: movie.id,
            title: movie.title,
            posterPath: movie.posterPath,
          );
          await box.put(preview.id, preview);
        }
      }
      return networkMovies;
    } catch (e) {
      if (page == 1 && box.isNotEmpty) {
        // If network fails, return data from cache
        final cachedPreviews = box.values.toList();
        return cachedPreviews
            .map((p) => Movie(id: p.id, title: p.title, posterPath: p.posterPath))
            .toList();
      }
      rethrow;
    }
  }
}
