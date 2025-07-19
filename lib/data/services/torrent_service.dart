import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/torrent.dart';

class TorrentService {
  static const String _baseUrl = 'API_URL';
  
  String get apiUrl => dotenv.env[_baseUrl] ?? 'http://localhost:3000';

  /// Получить торренты по IMDB ID
  /// [imdbId] - IMDB ID фильма/сериала (например, 'tt1234567')
  /// [type] - тип контента: 'movie' или 'tv'
  /// [season] - номер сезона для сериалов (опционально)
  Future<List<Torrent>> getTorrents({
    required String imdbId,
    required String type,
    int? season,
  }) async {
    try {
      final uri = Uri.parse('$apiUrl/torrents/search/$imdbId').replace(
        queryParameters: {
          'type': type,
          if (season != null) 'season': season.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];
        
        return results
            .map((json) => Torrent.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 404) {
        // Торренты не найдены - возвращаем пустой список
        return [];
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Ошибка загрузки торрентов: $e');
    }
  }

  /// Определить качество из названия торрента
  String? detectQuality(String title) {
    final titleLower = title.toLowerCase();
    
    // Порядок важен - сначала более специфичные паттерны
    if (titleLower.contains('2160p') || titleLower.contains('4k')) {
      return '4K';
    }
    if (titleLower.contains('1440p') || titleLower.contains('2k')) {
      return '1440p';
    }
    if (titleLower.contains('1080p')) {
      return '1080p';
    }
    if (titleLower.contains('720p')) {
      return '720p';
    }
    if (titleLower.contains('480p')) {
      return '480p';
    }
    if (titleLower.contains('360p')) {
      return '360p';
    }
    
    return null;
  }

  /// Группировать торренты по качеству
  Map<String, List<Torrent>> groupTorrentsByQuality(List<Torrent> torrents) {
    final groups = <String, List<Torrent>>{};
    
    for (final torrent in torrents) {
      final title = torrent.title ?? torrent.name ?? '';
      final quality = detectQuality(title) ?? 'Неизвестно';
      
      if (!groups.containsKey(quality)) {
        groups[quality] = [];
      }
      groups[quality]!.add(torrent);
    }
    
    // Сортируем торренты внутри каждой группы по количеству сидов (убывание)
    for (final group in groups.values) {
      group.sort((a, b) => (b.seeders ?? 0).compareTo(a.seeders ?? 0));
    }
    
    // Возвращаем группы в порядке качества (от высокого к низкому)
    final sortedGroups = <String, List<Torrent>>{};
    const qualityOrder = ['4K', '1440p', '1080p', '720p', '480p', '360p', 'Неизвестно'];
    
    for (final quality in qualityOrder) {
      if (groups.containsKey(quality) && groups[quality]!.isNotEmpty) {
        sortedGroups[quality] = groups[quality]!;
      }
    }
    
    return sortedGroups;
  }

  /// Получить доступные сезоны для сериала
  /// [imdbId] - IMDB ID сериала
  Future<List<int>> getAvailableSeasons(String imdbId) async {
    try {
      // Получаем все торренты для сериала без указания сезона
      final torrents = await getTorrents(imdbId: imdbId, type: 'tv');
      
      // Извлекаем номера сезонов из названий торрентов
      final seasons = <int>{};
      
      for (final torrent in torrents) {
        final title = torrent.title ?? torrent.name ?? '';
        final seasonRegex = RegExp(r'(?:s|сезон)[\s:]*(\d+)|(\d+)\s*сезон', caseSensitive: false);
        final matches = seasonRegex.allMatches(title);
        
        for (final match in matches) {
          final seasonStr = match.group(1) ?? match.group(2);
          if (seasonStr != null) {
            final seasonNumber = int.tryParse(seasonStr);
            if (seasonNumber != null && seasonNumber > 0) {
              seasons.add(seasonNumber);
            }
          }
        }
      }
      
      final sortedSeasons = seasons.toList()..sort();
      return sortedSeasons;
    } catch (e) {
      throw Exception('Ошибка получения списка сезонов: $e');
    }
  }
}
