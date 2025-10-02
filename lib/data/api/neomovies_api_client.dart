import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:neomovies_mobile/data/models/auth_response.dart';
import 'package:neomovies_mobile/data/models/favorite.dart';
import 'package:neomovies_mobile/data/models/movie.dart';
import 'package:neomovies_mobile/data/models/reaction.dart';
import 'package:neomovies_mobile/data/models/user.dart';
import 'package:neomovies_mobile/data/models/torrent.dart';
import 'package:neomovies_mobile/data/models/player/player_response.dart';

/// New API client for neomovies-api (Go-based backend)
/// This client provides improved performance and new features:
/// - Email verification flow
/// - Google OAuth support
/// - Torrent search via RedAPI
/// - Multiple player support (Alloha, Lumex, Vibix)
/// - Enhanced reactions system
class NeoMoviesApiClient {
  final http.Client _client;
  final String _baseUrl;
  final String _apiVersion = 'v1';

  NeoMoviesApiClient(this._client, {String? baseUrl})
      : _baseUrl = baseUrl ?? dotenv.env['API_URL'] ?? 'https://api.neomovies.ru';

  String get apiUrl => '$_baseUrl/api/$_apiVersion';

  // ============================================
  // Authentication Endpoints
  // ============================================

  /// Register a new user (sends verification code to email)
  /// Returns: {"success": true, "message": "Verification code sent"}
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final uri = Uri.parse('$apiUrl/auth/register');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
        'name': name,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Registration failed: ${response.body}');
    }
  }

  /// Verify email with code sent during registration
  /// Returns: AuthResponse with JWT token and user info
  Future<AuthResponse> verifyEmail({
    required String email,
    required String code,
  }) async {
    final uri = Uri.parse('$apiUrl/auth/verify');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'code': code,
      }),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Verification failed: ${response.body}');
    }
  }

  /// Resend verification code to email
  Future<void> resendVerificationCode(String email) async {
    final uri = Uri.parse('$apiUrl/auth/resend-code');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to resend code: ${response.body}');
    }
  }

  /// Login with email and password
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$apiUrl/auth/login');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  /// Get Google OAuth login URL
  /// User should be redirected to this URL in a WebView
  String getGoogleOAuthUrl() {
    return '$apiUrl/auth/google/login';
  }

  /// Refresh authentication token
  Future<AuthResponse> refreshToken(String refreshToken) async {
    final uri = Uri.parse('$apiUrl/auth/refresh');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refreshToken': refreshToken}),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Token refresh failed: ${response.body}');
    }
  }

  /// Get current user profile
  Future<User> getProfile() async {
    final uri = Uri.parse('$apiUrl/auth/profile');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to get profile: ${response.body}');
    }
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    final uri = Uri.parse('$apiUrl/auth/profile');
    final response = await _client.delete(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to delete account: ${response.body}');
    }
  }

  // ============================================
  // Movies Endpoints
  // ============================================

  /// Get popular movies
  Future<List<Movie>> getPopularMovies({int page = 1}) async {
    return _fetchMovies('/movies/popular', page: page);
  }

  /// Get top rated movies
  Future<List<Movie>> getTopRatedMovies({int page = 1}) async {
    return _fetchMovies('/movies/top-rated', page: page);
  }

  /// Get upcoming movies
  Future<List<Movie>> getUpcomingMovies({int page = 1}) async {
    return _fetchMovies('/movies/upcoming', page: page);
  }

  /// Get now playing movies
  Future<List<Movie>> getNowPlayingMovies({int page = 1}) async {
    return _fetchMovies('/movies/now-playing', page: page);
  }

  /// Get movie by ID
  Future<Movie> getMovieById(String id) async {
    final uri = Uri.parse('$apiUrl/movies/$id');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      return Movie.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load movie: ${response.statusCode}');
    }
  }

  /// Get movie recommendations
  Future<List<Movie>> getMovieRecommendations(String movieId, {int page = 1}) async {
    return _fetchMovies('/movies/$movieId/recommendations', page: page);
  }

  /// Search movies
  Future<List<Movie>> searchMovies(String query, {int page = 1}) async {
    return _fetchMovies('/movies/search', page: page, query: query);
  }

  // ============================================
  // TV Shows Endpoints
  // ============================================

  /// Get popular TV shows
  Future<List<Movie>> getPopularTvShows({int page = 1}) async {
    return _fetchMovies('/tv/popular', page: page);
  }

  /// Get top rated TV shows
  Future<List<Movie>> getTopRatedTvShows({int page = 1}) async {
    return _fetchMovies('/tv/top-rated', page: page);
  }

  /// Get TV show by ID
  Future<Movie> getTvShowById(String id) async {
    final uri = Uri.parse('$apiUrl/tv/$id');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      return Movie.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load TV show: ${response.statusCode}');
    }
  }

  /// Get TV show recommendations
  Future<List<Movie>> getTvShowRecommendations(String tvId, {int page = 1}) async {
    return _fetchMovies('/tv/$tvId/recommendations', page: page);
  }

  /// Search TV shows
  Future<List<Movie>> searchTvShows(String query, {int page = 1}) async {
    return _fetchMovies('/tv/search', page: page, query: query);
  }

  // ============================================
  // Unified Search
  // ============================================

  /// Search both movies and TV shows
  Future<List<Movie>> search(String query, {int page = 1}) async {
    final results = await Future.wait([
      searchMovies(query, page: page),
      searchTvShows(query, page: page),
    ]);
    
    // Combine and return
    return [...results[0], ...results[1]];
  }

  // ============================================
  // Favorites Endpoints
  // ============================================

  /// Get user's favorite movies/shows
  Future<List<Favorite>> getFavorites() async {
    final uri = Uri.parse('$apiUrl/favorites');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Favorite.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch favorites: ${response.body}');
    }
  }

  /// Add movie/show to favorites
  Future<void> addFavorite({
    required String mediaId,
    required String mediaType,
    required String title,
    required String posterPath,
  }) async {
    final uri = Uri.parse('$apiUrl/favorites');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'mediaId': mediaId,
        'mediaType': mediaType,
        'title': title,
        'posterPath': posterPath,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add favorite: ${response.body}');
    }
  }

  /// Remove movie/show from favorites
  Future<void> removeFavorite(String mediaId) async {
    final uri = Uri.parse('$apiUrl/favorites/$mediaId');
    final response = await _client.delete(uri);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to remove favorite: ${response.body}');
    }
  }

  // ============================================
  // Reactions Endpoints (NEW!)
  // ============================================

  /// Get reaction counts for a movie/show
  Future<Map<String, int>> getReactionCounts({
    required String mediaType,
    required String mediaId,
  }) async {
    final uri = Uri.parse('$apiUrl/reactions/$mediaType/$mediaId/counts');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Map<String, int>.from(data);
    } else {
      throw Exception('Failed to get reactions: ${response.body}');
    }
  }

  /// Add or update user's reaction
  Future<void> setReaction({
    required String mediaType,
    required String mediaId,
    required String reactionType, // 'like' or 'dislike'
  }) async {
    final uri = Uri.parse('$apiUrl/reactions/$mediaType/$mediaId');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'type': reactionType}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to set reaction: ${response.body}');
    }
  }

  /// Get user's own reactions
  Future<List<UserReaction>> getMyReactions() async {
    final uri = Uri.parse('$apiUrl/reactions/my');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => UserReaction.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get my reactions: ${response.body}');
    }
  }

  // ============================================
  // Torrent Search Endpoints (NEW!)
  // ============================================

  /// Search torrents for a movie/show via RedAPI
  /// @param imdbId - IMDb ID (e.g., "tt1234567")
  /// @param type - "movie" or "series"
  /// @param quality - "1080p", "720p", "480p", etc.
  Future<List<TorrentItem>> searchTorrents({
    required String imdbId,
    required String type,
    String? quality,
    String? season,
    String? episode,
  }) async {
    final queryParams = {
      'type': type,
      if (quality != null) 'quality': quality,
      if (season != null) 'season': season,
      if (episode != null) 'episode': episode,
    };

    final uri = Uri.parse('$apiUrl/torrents/search/$imdbId')
        .replace(queryParameters: queryParams);
    
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => TorrentItem.fromJson(json)).toList();
    } else {
      throw Exception('Failed to search torrents: ${response.body}');
    }
  }

  // ============================================
  // Players Endpoints (NEW!)
  // ============================================

  /// Get Alloha player embed URL
  Future<PlayerResponse> getAllohaPlayer(String imdbId) async {
    return _getPlayer('/players/alloha/$imdbId');
  }

  /// Get Lumex player embed URL
  Future<PlayerResponse> getLumexPlayer(String imdbId) async {
    return _getPlayer('/players/lumex/$imdbId');
  }

  /// Get Vibix player embed URL
  Future<PlayerResponse> getVibixPlayer(String imdbId) async {
    return _getPlayer('/players/vibix/$imdbId');
  }

  // ============================================
  // Private Helper Methods
  // ============================================

  /// Generic method to fetch movies/TV shows
  Future<List<Movie>> _fetchMovies(
    String endpoint, {
    int page = 1,
    String? query,
  }) async {
    final queryParams = {
      'page': page.toString(),
      if (query != null && query.isNotEmpty) 'query': query,
    };

    final uri = Uri.parse('$apiUrl$endpoint').replace(queryParameters: queryParams);
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      
      List<dynamic> results;
      if (decoded is List) {
        results = decoded;
      } else if (decoded is Map && decoded['results'] != null) {
        results = decoded['results'];
      } else {
        throw Exception('Unexpected response format');
      }

      return results.map((json) => Movie.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load from $endpoint: ${response.statusCode}');
    }
  }

  /// Generic method to fetch player info
  Future<PlayerResponse> _getPlayer(String endpoint) async {
    final uri = Uri.parse('$apiUrl$endpoint');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      return PlayerResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to get player: ${response.body}');
    }
  }
}
