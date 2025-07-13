import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:neomovies_mobile/data/models/auth_response.dart';
import 'package:neomovies_mobile/data/models/favorite.dart';
import 'package:neomovies_mobile/data/models/movie.dart';
import 'package:neomovies_mobile/data/models/reaction.dart';
import 'package:neomovies_mobile/data/models/user.dart';

class ApiClient {
  final http.Client _client;
  final String _baseUrl = dotenv.env['API_URL']!;

  ApiClient(this._client);

  Future<List<Movie>> getPopularMovies({int page = 1}) async {
    return _fetchMovies('/movies/popular', page: page);
  }

  Future<List<Movie>> getTopRatedMovies({int page = 1}) async {
    return _fetchMovies('/movies/top-rated', page: page);
  }

  Future<List<Movie>> getUpcomingMovies({int page = 1}) async {
    return _fetchMovies('/movies/upcoming', page: page);
  }

  Future<Movie> getMovieById(String id) async {
    return _fetchMovieDetail('/movies/$id');
  }

  Future<Movie> getTvById(String id) async {
    return _fetchMovieDetail('/tv/$id');
  }

  // Получение IMDB ID для фильмов
  Future<String?> getMovieImdbId(int movieId) async {
    try {
      final uri = Uri.parse('$_baseUrl/movies/$movieId/external-ids');
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['imdb_id'] as String?;
      } else {
        print('Failed to get movie IMDB ID: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting movie IMDB ID: $e');
      return null;
    }
  }

  // Получение IMDB ID для сериалов
  Future<String?> getTvImdbId(int showId) async {
    try {
      final uri = Uri.parse('$_baseUrl/tv/$showId/external-ids');
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['imdb_id'] as String?;
      } else {
        print('Failed to get TV IMDB ID: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting TV IMDB ID: $e');
      return null;
    }
  }

  // Универсальный метод получения IMDB ID
  Future<String?> getImdbId(int mediaId, String mediaType) async {
    if (mediaType == 'tv') {
      return getTvImdbId(mediaId);
    } else {
      return getMovieImdbId(mediaId);
    }
  }

  Future<List<Movie>> searchMovies(String query, {int page = 1}) async {
    final moviesUri = Uri.parse('$_baseUrl/movies/search?query=${Uri.encodeQueryComponent(query)}&page=$page');
    final tvUri = Uri.parse('$_baseUrl/tv/search?query=${Uri.encodeQueryComponent(query)}&page=$page');

    final responses = await Future.wait([
      _client.get(moviesUri),
      _client.get(tvUri),
    ]);

    List<Movie> combined = [];

    for (final response in responses) {
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> listData;
        if (decoded is List) {
          listData = decoded;
        } else if (decoded is Map && decoded['results'] is List) {
          listData = decoded['results'];
        } else {
          listData = [];
        }
        combined.addAll(listData.map((json) => Movie.fromJson(json)));
      } else {
        // ignore non-200 but log maybe
      }
    }

    if (combined.isEmpty) {
      throw Exception('Failed to search movies/tv');
    }
    return combined;
  }

  Future<Movie> _fetchMovieDetail(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Movie.fromJson(data);
    } else {
      throw Exception('Failed to load media details: ${response.statusCode}');
    }
  }

  // Favorites
  Future<List<Favorite>> getFavorites() async {
    final response = await _client.get(Uri.parse('$_baseUrl/favorites'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Favorite.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch favorites');
    }
  }

  Future<void> addFavorite(String mediaId, String mediaType, String title, String posterPath) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/favorites/$mediaId?mediaType=$mediaType'),
      body: json.encode({
        'title': title,
        'posterPath': posterPath,
      }),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to add favorite');
    }
  }

  Future<void> removeFavorite(String mediaId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/favorites/$mediaId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove favorite');
    }
  }

  // Reactions
  Future<Map<String, int>> getReactionCounts(String mediaType, String mediaId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/reactions/$mediaType/$mediaId/counts'),
    );

    print('REACTION COUNTS RESPONSE (${response.statusCode}): ${response.body}');

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      print('PARSED: $decoded');
      
      if (decoded is Map) {
        final mapSrc = decoded.containsKey('data') && decoded['data'] is Map
            ? decoded['data'] as Map<String, dynamic>
            : decoded;
            
        print('MAPPING: $mapSrc');
        return mapSrc.map((k, v) {
          int count;
          if (v is num) {
            count = v.toInt();
          } else if (v is String) {
            count = int.tryParse(v) ?? 0;
          } else {
            count = 0;
          }
          return MapEntry(k, count);
        });
      }
      if (decoded is List) {
        // list of {type,count}
        Map<String, int> res = {};
        for (var item in decoded) {
          if (item is Map && item['type'] != null) {
            res[item['type'].toString()] = (item['count'] as num?)?.toInt() ?? 0;
          }
        }
        return res;
      }
      return {};
    } else {
      throw Exception('Failed to fetch reactions counts');
    }
  }

  Future<UserReaction> getMyReaction(String mediaType, String mediaId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/reactions/$mediaType/$mediaId/my-reaction'),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded == null || (decoded is String && decoded.isEmpty)) {
        return UserReaction(reactionType: null);
      }
      return UserReaction.fromJson(decoded as Map<String, dynamic>);
    } else if (response.statusCode == 404) {
      return UserReaction(reactionType: 'none'); // No reaction found
    } else {
      throw Exception('Failed to fetch user reaction');
    }
  }

  Future<void> setReaction(String mediaType, String mediaId, String reactionType) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/reactions'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'mediaId': '${mediaType}_${mediaId}', 'type': reactionType}),
    );

    if (response.statusCode != 201 && response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to set reaction: ${response.statusCode} ${response.body}');
    }
  }

  // --- Auth Methods ---

  Future<void> register(String name, String email, String password) async {
    final uri = Uri.parse('$_baseUrl/auth/register');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'email': email, 'password': password}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      if (decoded['success'] == true || decoded.containsKey('token')) {
        // registration succeeded; nothing further to return
        return;
      } else {
        throw Exception('Failed to register: ${decoded['message'] ?? 'Unknown error'}');
      }
    } else {
      throw Exception('Failed to register: ${response.statusCode} ${response.body}');
    }
  }

  Future<AuthResponse> login(String email, String password) async {
    final uri = Uri.parse('$_baseUrl/auth/login');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  Future<void> verify(String email, String code) async {
    final uri = Uri.parse('$_baseUrl/auth/verify');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'code': code}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to verify code: ${response.body}');
    }
  }

  Future<void> resendCode(String email) async {
    final uri = Uri.parse('$_baseUrl/auth/resend-code');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to resend code: ${response.body}');
    }
  }

  Future<void> deleteAccount() async {
    final uri = Uri.parse('$_baseUrl/auth/profile');
    final response = await _client.delete(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to delete account: ${response.body}');
    }
  }

  // --- Movie Methods ---

  Future<List<Movie>> _fetchMovies(String endpoint, {int page = 1}) async {
    final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: {
      'page': page.toString(),
    });
    final response = await _client.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body)['results'];
      if (data == null) {
        return [];
      }
      return data.map((json) => Movie.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load movies from $endpoint');
    }
  }
}
