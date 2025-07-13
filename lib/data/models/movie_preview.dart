import 'package:hive/hive.dart';

part 'movie_preview.g.dart';

@HiveType(typeId: 1) // Use a new typeId to avoid conflicts with Movie
class MoviePreview extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? posterPath;

  MoviePreview({
    required this.id,
    required this.title,
    this.posterPath,
  });
}
