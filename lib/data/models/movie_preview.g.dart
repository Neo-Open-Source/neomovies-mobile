// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_preview.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MoviePreviewAdapter extends TypeAdapter<MoviePreview> {
  @override
  final int typeId = 1;

  @override
  MoviePreview read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MoviePreview(
      id: fields[0] as String,
      title: fields[1] as String,
      posterPath: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MoviePreview obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.posterPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoviePreviewAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoviePreview _$MoviePreviewFromJson(Map<String, dynamic> json) => MoviePreview(
      id: json['id'] as String,
      title: json['title'] as String,
      posterPath: json['posterPath'] as String?,
    );

Map<String, dynamic> _$MoviePreviewToJson(MoviePreview instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'posterPath': instance.posterPath,
    };
