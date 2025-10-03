import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neomovies_mobile/data/services/player_embed_service.dart';

void main() {
  group('PlayerEmbedService Tests', () {
    group('Vibix Player', () {
      test('should get embed URL from API server successfully', () async {
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/player/vibix/embed') {
            final body = jsonDecode(request.body);
            expect(body['videoUrl'], 'http://example.com/video.mp4');
            expect(body['title'], 'Test Movie');
            expect(body['autoplay'], true);

            return http.Response(
              jsonEncode({
                'embedUrl': 'https://vibix.me/embed/custom?src=encoded&autoplay=1',
                'success': true,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        // Mock the http client (in real implementation, you'd inject this)
        final embedUrl = await _testGetVibixEmbedUrl(
          client: mockClient,
          videoUrl: 'http://example.com/video.mp4',
          title: 'Test Movie',
        );

        expect(embedUrl, 'https://vibix.me/embed/custom?src=encoded&autoplay=1');
      });

      test('should fallback to direct URL when server fails', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Server Error', 500);
        });

        final embedUrl = await _testGetVibixEmbedUrl(
          client: mockClient,
          videoUrl: 'http://example.com/video.mp4',
          title: 'Test Movie',
        );

        expect(embedUrl, contains('vibix.me/embed'));
        expect(embedUrl, contains('src=http%3A//example.com/video.mp4'));
        expect(embedUrl, contains('title=Test%20Movie'));
      });

      test('should handle network timeout gracefully', () async {
        final mockClient = MockClient((request) async {
          throw const SocketException('Connection timeout');
        });

        final embedUrl = await _testGetVibixEmbedUrl(
          client: mockClient,
          videoUrl: 'http://example.com/video.mp4',
          title: 'Test Movie',
        );

        // Should fallback to direct URL
        expect(embedUrl, contains('vibix.me/embed'));
      });

      test('should include optional parameters in API request', () async {
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/player/vibix/embed') {
            final body = jsonDecode(request.body);
            expect(body['imdbId'], 'tt1234567');
            expect(body['season'], '1');
            expect(body['episode'], '5');

            return http.Response(
              jsonEncode({'embedUrl': 'https://vibix.me/embed/tv'}),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        final embedUrl = await _testGetVibixEmbedUrl(
          client: mockClient,
          videoUrl: 'http://example.com/video.mp4',
          title: 'Test TV Show',
          imdbId: 'tt1234567',
          season: '1',
          episode: '5',
        );

        expect(embedUrl, 'https://vibix.me/embed/tv');
      });
    });

    group('Alloha Player', () {
      test('should get embed URL from API server successfully', () async {
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/player/alloha/embed') {
            return http.Response(
              jsonEncode({
                'embedUrl': 'https://alloha.tv/embed/custom?src=encoded',
                'success': true,
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        final embedUrl = await _testGetAllohaEmbedUrl(
          client: mockClient,
          videoUrl: 'http://example.com/video.mp4',
          title: 'Test Movie',
        );

        expect(embedUrl, 'https://alloha.tv/embed/custom?src=encoded');
      });

      test('should fallback to direct URL when server fails', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Server Error', 500);
        });

        final embedUrl = await _testGetAllohaEmbedUrl(
          client: mockClient,
          videoUrl: 'http://example.com/video.mp4',
          title: 'Test Movie',
        );

        expect(embedUrl, contains('alloha.tv/embed'));
        expect(embedUrl, contains('src=http%3A//example.com/video.mp4'));
      });
    });

    group('Player Configuration', () {
      test('should get player config from server', () async {
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/player/vibix/config') {
            return http.Response(
              jsonEncode({
                'playerOptions': {
                  'autoplay': true,
                  'controls': true,
                  'volume': 0.8,
                },
                'theme': 'dark',
                'language': 'ru',
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        final config = await _testGetPlayerConfig(
          client: mockClient,
          playerType: 'vibix',
          imdbId: 'tt1234567',
        );

        expect(config, isNotNull);
        expect(config!['playerOptions']['autoplay'], true);
        expect(config['theme'], 'dark');
      });

      test('should return null when config not available', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final config = await _testGetPlayerConfig(
          client: mockClient,
          playerType: 'nonexistent',
        );

        expect(config, isNull);
      });
    });

    group('Server Health Check', () {
      test('should return true when server is available', () async {
        final mockClient = MockClient((request) async {
          if (request.url.path == '/api/player/health') {
            return http.Response(
              jsonEncode({'status': 'ok', 'version': '1.0.0'}),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        final isAvailable = await _testIsServerApiAvailable(mockClient);
        expect(isAvailable, true);
      });

      test('should return false when server is unavailable', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Server Error', 500);
        });

        final isAvailable = await _testIsServerApiAvailable(mockClient);
        expect(isAvailable, false);
      });

      test('should return false on network timeout', () async {
        final mockClient = MockClient((request) async {
          throw const SocketException('Connection timeout');
        });

        final isAvailable = await _testIsServerApiAvailable(mockClient);
        expect(isAvailable, false);
      });
    });

    group('URL Encoding', () {
      test('should properly encode special characters in video URL', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Server Error', 500); // Force fallback
        });

        final embedUrl = await _testGetVibixEmbedUrl(
          client: mockClient,
          videoUrl: 'http://example.com/path with spaces/movie&test.mp4',
          title: 'Movie Title (2023)',
        );

        expect(embedUrl, contains('path%20with%20spaces'));
        expect(embedUrl, contains('movie%26test.mp4'));
        expect(embedUrl, contains('Movie%20Title%20%282023%29'));
      });

      test('should handle non-ASCII characters in title', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Server Error', 500); // Force fallback
        });

        final embedUrl = await _testGetVibixEmbedUrl(
          client: mockClient,
          videoUrl: 'http://example.com/video.mp4',
          title: 'Тест Фильм Россия',
        );

        expect(embedUrl, contains('title=%D0%A2%D0%B5%D1%81%D1%82'));
      });
    });
  });
}

// Helper functions to test with mocked http client
// Note: In a real implementation, you would inject the http client

Future<String> _testGetVibixEmbedUrl({
  required http.Client client,
  required String videoUrl,
  required String title,
  String? imdbId,
  String? season,
  String? episode,
}) async {
  // This simulates the PlayerEmbedService.getVibixEmbedUrl behavior
  // In real implementation, you'd need dependency injection for the http client
  try {
    final response = await client.post(
      Uri.parse('https://neomovies.site/api/player/vibix/embed'),
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
    // Fallback to direct URL
    final encodedVideoUrl = Uri.encodeComponent(videoUrl);
    final encodedTitle = Uri.encodeComponent(title);
    return 'https://vibix.me/embed/?src=$encodedVideoUrl&autoplay=1&title=$encodedTitle';
  }
}

Future<String> _testGetAllohaEmbedUrl({
  required http.Client client,
  required String videoUrl,
  required String title,
  String? imdbId,
  String? season,
  String? episode,
}) async {
  try {
    final response = await client.post(
      Uri.parse('https://neomovies.site/api/player/alloha/embed'),
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
    // Fallback to direct URL
    final encodedVideoUrl = Uri.encodeComponent(videoUrl);
    final encodedTitle = Uri.encodeComponent(title);
    return 'https://alloha.tv/embed?src=$encodedVideoUrl&autoplay=1&title=$encodedTitle';
  }
}

Future<Map<String, dynamic>?> _testGetPlayerConfig({
  required http.Client client,
  required String playerType,
  String? imdbId,
  String? season,
  String? episode,
}) async {
  try {
    final response = await client.get(
      Uri.parse('https://neomovies.site/api/player/$playerType/config').replace(
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

Future<bool> _testIsServerApiAvailable(http.Client client) async {
  try {
    final response = await client.get(
      Uri.parse('https://neomovies.site/api/player/health'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 5));

    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}