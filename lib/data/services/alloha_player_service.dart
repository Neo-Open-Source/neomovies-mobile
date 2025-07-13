// lib/data/services/alloha_player_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:neomovies_mobile/data/models/player/video_quality.dart';
import 'package:neomovies_mobile/data/models/player/audio_track.dart';
import 'package:neomovies_mobile/data/models/player/subtitle.dart';

class AllohaPlayerService {
  static const String _baseUrl = 'https://neomovies.site'; // Replace with actual base URL

  Future<Map<String, dynamic>> getStreamInfo(String mediaId, String mediaType) async {
    try {
      // First, get the player page
      final response = await http.get(
        Uri.parse('$_baseUrl/$mediaType/$mediaId/player'),
      );

      if (response.statusCode == 200) {
        // Parse the response to extract stream information
        return _parsePlayerPage(response.body);
      } else {
        throw Exception('Failed to load player page: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting stream info: $e');
    }
  }

  Map<String, dynamic> _parsePlayerPage(String html) {
    // TODO: Implement actual HTML parsing based on the Alloha player page structure
    // This is a placeholder - you'll need to update this based on the actual HTML structure
    
    // Example structure (replace with actual parsing):
    return {
      'streamUrl': 'https://example.com/stream.m3u8',
      'qualities': [
        {'name': '1080p', 'resolution': '1920x1080', 'url': '...'},
        {'name': '720p', 'resolution': '1280x720', 'url': '...'},
      ],
      'audioTracks': [
        {'id': 'ru', 'name': 'Русский', 'language': 'ru', 'isDefault': true},
        {'id': 'en', 'name': 'English', 'language': 'en'},
      ],
      'subtitles': [
        {'id': 'ru', 'name': 'Русские', 'language': 'ru', 'url': '...'},
        {'id': 'en', 'name': 'English', 'language': 'en', 'url': '...'},
      ],
    };
  }

  // Convert parsed data to our models
  List<VideoQuality> parseQualities(List<dynamic> qualities) {
    return qualities.map((q) => VideoQuality(
      name: q['name'],
      resolution: q['resolution'],
      url: q['url'],
    )).toList();
  }

  List<AudioTrack> parseAudioTracks(List<dynamic> tracks) {
    return tracks.map((t) => AudioTrack(
      id: t['id'],
      name: t['name'],
      language: t['language'],
      isDefault: t['isDefault'] ?? false,
    )).toList();
  }

  List<Subtitle> parseSubtitles(List<dynamic> subtitles) {
    return subtitles.map((s) => Subtitle(
      id: s['id'],
      name: s['name'],
      language: s['language'],
      url: s['url'],
    )).toList();
  }
}