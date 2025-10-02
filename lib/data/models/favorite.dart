import 'package:flutter_dotenv/flutter_dotenv.dart';

class Favorite {
  final String id; // MongoDB ObjectID as string
  final String mediaId;
  final String mediaType; // "movie" or "tv"
  final String title;
  final String posterPath;
  final DateTime? createdAt;

  Favorite({
    required this.id,
    required this.mediaId,
    required this.mediaType,
    required this.title,
    required this.posterPath,
    this.createdAt,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'] as String? ?? '',
      mediaId: json['mediaId'] as String? ?? '',
      mediaType: json['mediaType'] as String? ?? 'movie',
      title: json['title'] as String? ?? '',
      posterPath: json['posterPath'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  String get fullPosterUrl {
    if (posterPath.isEmpty) {
      return 'https://via.placeholder.com/500x750.png?text=No+Poster';
    }
    // TMDB CDN base URL
    const tmdbBaseUrl = 'https://image.tmdb.org/t/p';
    final cleanPath = posterPath.startsWith('/') ? posterPath.substring(1) : posterPath;
    return '$tmdbBaseUrl/w500/$cleanPath';
  }
}
