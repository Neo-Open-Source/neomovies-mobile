// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'torrent.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TorrentImpl _$$TorrentImplFromJson(Map<String, dynamic> json) =>
    _$TorrentImpl(
      magnet: json['magnet'] as String,
      title: json['title'] as String?,
      name: json['name'] as String?,
      quality: json['quality'] as String?,
      seeders: (json['seeders'] as num?)?.toInt(),
      sizeGb: (json['size_gb'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$TorrentImplToJson(_$TorrentImpl instance) =>
    <String, dynamic>{
      'magnet': instance.magnet,
      'title': instance.title,
      'name': instance.name,
      'quality': instance.quality,
      'seeders': instance.seeders,
      'size_gb': instance.sizeGb,
    };
