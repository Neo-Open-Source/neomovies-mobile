import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'movie.g.dart';

@HiveType(typeId: 0)
@JsonSerializable()
class Movie extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? posterPath;

  @HiveField(3)
  final String? overview;

  @HiveField(4)
  final DateTime? releaseDate;

  @HiveField(5)
  final List<String>? genres;

  @HiveField(6)
  final double? voteAverage;

  // Поле популярности из API (TMDB-style)
  @HiveField(9)
  final double popularity;

  @HiveField(7)
  final int? runtime;

  // TV specific
  @HiveField(10)
  final int? seasonsCount;
  @HiveField(11)
  final int? episodesCount;

  @HiveField(8)
  final String? tagline;

  // not stored in Hive, runtime-only field
  final String mediaType;

  Movie({
    required this.id,
    required this.title,
    this.posterPath,
    this.overview,
    this.releaseDate,
    this.genres,
    this.voteAverage,
    this.popularity = 0.0,
    this.runtime,
    this.seasonsCount,
    this.episodesCount,
    this.tagline,
    this.mediaType = 'movie',
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: (json['id'] as num).toString(), // Ensure id is a string
      title: (json['title'] ?? json['name'] ?? '') as String,
      posterPath: json['poster_path'] as String?,
      overview: json['overview'] as String?,
      releaseDate: json['release_date'] != null && json['release_date'].isNotEmpty
          ? DateTime.tryParse(json['release_date'] as String)
          : json['first_air_date'] != null && json['first_air_date'].isNotEmpty
              ? DateTime.tryParse(json['first_air_date'] as String)
              : null,
      genres: List<String>.from(json['genres']?.map((g) => g['name']) ?? []),
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0.0,
      runtime: json['runtime'] is num
          ? (json['runtime'] as num).toInt()
          : (json['episode_run_time'] is List && (json['episode_run_time'] as List).isNotEmpty)
              ? ((json['episode_run_time'] as List).first as num).toInt()
              : null,
      seasonsCount: json['number_of_seasons'] as int?,
      episodesCount: json['number_of_episodes'] as int?,
      tagline: json['tagline'] as String?,
      mediaType: (json['media_type'] ?? (json['title'] != null ? 'movie' : 'tv')) as String,
    );
  }

  Map<String, dynamic> toJson() => _$MovieToJson(this);

  String get fullPosterUrl {
    final baseUrl = dotenv.env['API_URL']!;
    if (posterPath == null || posterPath!.isEmpty) {
      // Use the placeholder from our own backend
      return '$baseUrl/images/w500/placeholder.jpg';
    }
    // Null check is already performed above, so we can use `!`
    final cleanPath = posterPath!.startsWith('/') ? posterPath!.substring(1) : posterPath!;
    return '$baseUrl/images/w500/$cleanPath';
  }
}
