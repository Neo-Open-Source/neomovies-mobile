import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'movie_preview.g.dart';

@HiveType(typeId: 1) // Use a new typeId to avoid conflicts with Movie
@JsonSerializable()
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

  factory MoviePreview.fromJson(Map<String, dynamic> json) => _$MoviePreviewFromJson(json);
  Map<String, dynamic> toJson() => _$MoviePreviewToJson(this);
}
