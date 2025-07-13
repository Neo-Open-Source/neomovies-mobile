import 'package:flutter_dotenv/flutter_dotenv.dart';

class Favorite {
  final int id;
  final String mediaId;
  final String mediaType;
  final String title;
  final String posterPath;

  Favorite({
    required this.id,
    required this.mediaId,
    required this.mediaType,
    required this.title,
    required this.posterPath,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'] as int? ?? 0,
      mediaId: json['mediaId'] as String? ?? '',
      mediaType: json['mediaType'] as String? ?? '',
      title: json['title'] as String? ?? '',
      posterPath: json['posterPath'] as String? ?? '',
    );
  }

  String get fullPosterUrl {
    final baseUrl = dotenv.env['API_URL']!;
    if (posterPath.isEmpty) {
      return '$baseUrl/images/w500/placeholder.jpg';
    }
    final cleanPath = posterPath.startsWith('/') ? posterPath.substring(1) : posterPath;
    return '$baseUrl/images/w500/$cleanPath';
  }
}
