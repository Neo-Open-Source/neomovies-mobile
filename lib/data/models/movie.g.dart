// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MovieAdapter extends TypeAdapter<Movie> {
  @override
  final int typeId = 0;

  @override
  Movie read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Movie(
      id: fields[0] as String,
      title: fields[1] as String,
      posterPath: fields[2] as String?,
      overview: fields[3] as String?,
      releaseDate: fields[4] as DateTime?,
      genres: (fields[5] as List?)?.cast<String>(),
      voteAverage: fields[6] as double?,
      popularity: fields[9] as double,
      runtime: fields[7] as int?,
      seasonsCount: fields[10] as int?,
      episodesCount: fields[11] as int?,
      tagline: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Movie obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.posterPath)
      ..writeByte(3)
      ..write(obj.overview)
      ..writeByte(4)
      ..write(obj.releaseDate)
      ..writeByte(5)
      ..write(obj.genres)
      ..writeByte(6)
      ..write(obj.voteAverage)
      ..writeByte(9)
      ..write(obj.popularity)
      ..writeByte(7)
      ..write(obj.runtime)
      ..writeByte(10)
      ..write(obj.seasonsCount)
      ..writeByte(11)
      ..write(obj.episodesCount)
      ..writeByte(8)
      ..write(obj.tagline);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MovieAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Movie _$MovieFromJson(Map<String, dynamic> json) => Movie(
      id: json['id'] as String,
      title: json['title'] as String,
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      overview: json['overview'] as String?,
      releaseDate: json['releaseDate'] == null
          ? null
          : DateTime.parse(json['releaseDate'] as String),
      genres:
          (json['genres'] as List<dynamic>?)?.map((e) => e as String).toList(),
      voteAverage: (json['voteAverage'] as num?)?.toDouble(),
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0.0,
      runtime: (json['runtime'] as num?)?.toInt(),
      seasonsCount: (json['seasonsCount'] as num?)?.toInt(),
      episodesCount: (json['episodesCount'] as num?)?.toInt(),
      tagline: json['tagline'] as String?,
      mediaType: json['mediaType'] as String? ?? 'movie',
    );

Map<String, dynamic> _$MovieToJson(Movie instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'posterPath': instance.posterPath,
      'backdropPath': instance.backdropPath,
      'overview': instance.overview,
      'releaseDate': instance.releaseDate?.toIso8601String(),
      'genres': instance.genres,
      'voteAverage': instance.voteAverage,
      'popularity': instance.popularity,
      'runtime': instance.runtime,
      'seasonsCount': instance.seasonsCount,
      'episodesCount': instance.episodesCount,
      'tagline': instance.tagline,
      'mediaType': instance.mediaType,
    };
