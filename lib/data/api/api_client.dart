import 'package:http/http.dart' as http;
import 'package:neomovies_mobile/data/models/movie.dart';
import 'package:neomovies_mobile/data/models/favorite.dart';
import 'package:neomovies_mobile/data/models/reaction.dart';
import 'package:neomovies_mobile/data/models/auth_response.dart';
import 'package:neomovies_mobile/data/models/user.dart';
import 'package:neomovies_mobile/data/api/neomovies_api_client.dart'; // новый клиент

class ApiClient {
  final NeoMoviesApiClient _neoClient;

  ApiClient(http.Client client)
      : _neoClient = NeoMoviesApiClient(client);

  // ---- Movies ----
  Future<List<Movie>> getPopularMovies({int page = 1}) {
    return _neoClient.getPopularMovies(page: page);
  }

  Future<List<Movie>> getTopRatedMovies({int page = 1}) {
    return _neoClient.getTopRatedMovies(page: page);
  }

  Future<List<Movie>> getUpcomingMovies({int page = 1}) {
    return _neoClient.getUpcomingMovies(page: page);
  }

  Future<Movie> getMovieById(String id) {
    return _neoClient.getMovieById(id);
  }

  Future<Movie> getTvById(String id) {
    return _neoClient.getTvShowById(id);
  }

  // ---- Search ----
  Future<List<Movie>> searchMovies(String query, {int page = 1}) {
    return _neoClient.search(query, page: page);
  }

  // ---- Favorites ----
  Future<List<Favorite>> getFavorites() {
    return _neoClient.getFavorites();
  }

  Future<void> addFavorite(
    String mediaId,
    String mediaType,
    String title,
    String posterPath,
  ) {
    return _neoClient.addFavorite(
      mediaId: mediaId,
      mediaType: mediaType,
      title: title,
      posterPath: posterPath,
    );
  }

  Future<void> removeFavorite(String mediaId) {
    return _neoClient.removeFavorite(mediaId);
  }

  // ---- Reactions ----
  Future<Map<String, int>> getReactionCounts(
      String mediaType, String mediaId) {
    return _neoClient.getReactionCounts(
      mediaType: mediaType,
      mediaId: mediaId,
    );
  }

  Future<void> setReaction(
      String mediaType, String mediaId, String reactionType) {
    return _neoClient.setReaction(
      mediaType: mediaType,
      mediaId: mediaId,
      reactionType: reactionType,
    );
  }

  Future<List<UserReaction>> getMyReactions() {
    return _neoClient.getMyReactions();
  }

  // Get single user reaction for specific media
  Future<UserReaction?> getMyReaction(String mediaType, String mediaId) async {
    final reactions = await _neoClient.getMyReactions();
    try {
      return reactions.firstWhere(
        (r) => r.mediaType == mediaType && r.mediaId == mediaId,
      );
    } catch (e) {
      return null; // No reaction found
    }
  }

  // ---- External IDs (IMDb) ----
  Future<String?> getImdbId(String mediaId, String mediaType) async {
    // This would need to be implemented in NeoMoviesApiClient
    // For now, return null or implement a stub
    // TODO: Add getExternalIds endpoint to backend
    return null;
  }

  // ---- Auth ----
  Future<void> register(String name, String email, String password) {
    return _neoClient.register(
      name: name,
      email: email,
      password: password,
    ).then((_) {}); // старый код ничего не возвращал
  }

  Future<AuthResponse> login(String email, String password) {
    return _neoClient.login(email: email, password: password);
  }

  Future<void> verify(String email, String code) {
    return _neoClient.verifyEmail(email: email, code: code).then((_) {});
  }

  Future<void> resendCode(String email) {
    return _neoClient.resendVerificationCode(email);
  }

  Future<void> deleteAccount() {
    return _neoClient.deleteAccount();
  }
}