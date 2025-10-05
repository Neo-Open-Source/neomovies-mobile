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

  final String? backdropPath;

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
    this.backdropPath,
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
    try {
      print('Parsing Movie from JSON: ${json.keys.toList()}');
      
      // Parse genres safely - API returns: [{"id": 18, "name": "Drama"}]
      List<String> genresList = [];
      if (json['genres'] != null && json['genres'] is List) {
        genresList = (json['genres'] as List)
            .map((g) {
              if (g is Map && g.containsKey('name')) {
                return g['name'] as String? ?? '';
              }
              return '';
            })
            .where((name) => name.isNotEmpty)
            .toList();
        print('Parsed genres: $genresList');
      }

      // Parse dates safely
      DateTime? parsedDate;
      final releaseDate = json['release_date'];
      final firstAirDate = json['first_air_date'];
      
      if (releaseDate != null && releaseDate.toString().isNotEmpty && releaseDate.toString() != 'null') {
        parsedDate = DateTime.tryParse(releaseDate.toString());
      } else if (firstAirDate != null && firstAirDate.toString().isNotEmpty && firstAirDate.toString() != 'null') {
        parsedDate = DateTime.tryParse(firstAirDate.toString());
      }

      // Parse runtime (movie) or episode_run_time (TV)
      int? runtimeValue;
      if (json['runtime'] != null && json['runtime'] is num && (json['runtime'] as num) > 0) {
        runtimeValue = (json['runtime'] as num).toInt();
      } else if (json['episode_run_time'] != null && json['episode_run_time'] is List) {
        final episodeRunTime = json['episode_run_time'] as List;
        if (episodeRunTime.isNotEmpty && episodeRunTime.first is num) {
          runtimeValue = (episodeRunTime.first as num).toInt();
        }
      }

      // Determine media type
      String mediaTypeValue = 'movie';
      if (json.containsKey('media_type') && json['media_type'] != null) {
        mediaTypeValue = json['media_type'] as String;
      } else if (json.containsKey('name') || json.containsKey('first_air_date')) {
        mediaTypeValue = 'tv';
      }

      final movie = Movie(
        id: (json['id'] as num).toString(),
        title: (json['title'] ?? json['name'] ?? 'Untitled') as String,
        posterPath: json['poster_path'] as String?,
        backdropPath: json['backdrop_path'] as String?,
        overview: json['overview'] as String?,
        releaseDate: parsedDate,
        genres: genresList,
        voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
        popularity: (json['popularity'] as num?)?.toDouble() ?? 0.0,
        runtime: runtimeValue,
        seasonsCount: json['number_of_seasons'] as int?,
        episodesCount: json['number_of_episodes'] as int?,
        tagline: json['tagline'] as String?,
        mediaType: mediaTypeValue,
      );

      print('Successfully parsed movie: ${movie.title}');
      return movie;
    } catch (e, stackTrace) {
      print('❌ Error parsing Movie from JSON: $e');
      print('Stack trace: $stackTrace');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => _$MovieToJson(this);

  String get fullPosterUrl {
    if (posterPath == null || posterPath!.isEmpty) {
      // Use API placeholder
      final apiUrl = dotenv.env['API_URL'] ?? 'https://api.neomovies.ru';
      return '$apiUrl/api/v1/images/w500/placeholder.jpg';
    }
    // Use NeoMovies API images endpoint instead of TMDB directly
    final apiUrl = dotenv.env['API_URL'] ?? 'https://api.neomovies.ru';
    final cleanPath = posterPath!.startsWith('/') ? posterPath!.substring(1) : posterPath!;
    return '$apiUrl/api/v1/images/w500/$cleanPath';
  }

  String get fullBackdropUrl {
    if (backdropPath == null || backdropPath!.isEmpty) {
      // Use API placeholder
      final apiUrl = dotenv.env['API_URL'] ?? 'https://api.neomovies.ru';
      return '$apiUrl/api/v1/images/w780/placeholder.jpg';
    }
    // Use NeoMovies API images endpoint instead of TMDB directly
    final apiUrl = dotenv.env['API_URL'] ?? 'https://api.neomovies.ru';
    final cleanPath = backdropPath!.startsWith('/') ? backdropPath!.substring(1) : backdropPath!;
    return '$apiUrl/api/v1/images/w780/$cleanPath';
  }
}
