import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for getting player embed URLs from NeoMovies API server
class PlayerEmbedService {
  static const String _baseUrl = 'https://neomovies.site'; // Replace with actual base URL
  
  /// Get Vibix player embed URL from server
  static Future<String> getVibixEmbedUrl({
    required String videoUrl,
    required String title,
    String? imdbId,
    String? season,
    String? episode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/player/vibix/embed'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'videoUrl': videoUrl,
          'title': title,
          'imdbId': imdbId,
          'season': season,
          'episode': episode,
          'autoplay': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['embedUrl'] as String;
      } else {
        throw Exception('Failed to get Vibix embed URL: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to direct URL if server is unavailable
      final encodedVideoUrl = Uri.encodeComponent(videoUrl);
      final encodedTitle = Uri.encodeComponent(title);
      return 'https://vibix.me/embed/?src=$encodedVideoUrl&autoplay=1&title=$encodedTitle';
    }
  }

  /// Get Alloha player embed URL from server
  static Future<String> getAllohaEmbedUrl({
    required String videoUrl,
    required String title,
    String? imdbId,
    String? season,
    String? episode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/player/alloha/embed'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'videoUrl': videoUrl,
          'title': title,
          'imdbId': imdbId,
          'season': season,
          'episode': episode,
          'autoplay': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['embedUrl'] as String;
      } else {
        throw Exception('Failed to get Alloha embed URL: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to direct URL if server is unavailable
      final encodedVideoUrl = Uri.encodeComponent(videoUrl);
      final encodedTitle = Uri.encodeComponent(title);
      return 'https://alloha.tv/embed?src=$encodedVideoUrl&autoplay=1&title=$encodedTitle';
    }
  }

  /// Get player configuration from server
  static Future<Map<String, dynamic>?> getPlayerConfig({
    required String playerType,
    String? imdbId,
    String? season,
    String? episode,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/player/$playerType/config').replace(
          queryParameters: {
            if (imdbId != null) 'imdbId': imdbId,
            if (season != null) 'season': season,
            if (episode != null) 'episode': episode,
          },
        ),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Check if server player API is available
  static Future<bool> isServerApiAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/player/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}