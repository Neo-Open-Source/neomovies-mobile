// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'torrent_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TorrentItem _$TorrentItemFromJson(Map<String, dynamic> json) => TorrentItem(
      title: json['title'] as String?,
      magnetUrl: json['magnetUrl'] as String?,
      quality: json['quality'] as String?,
      seeders: (json['seeders'] as num?)?.toInt(),
      leechers: (json['leechers'] as num?)?.toInt(),
      size: json['size'] as String?,
      source: json['source'] as String?,
    );

Map<String, dynamic> _$TorrentItemToJson(TorrentItem instance) =>
    <String, dynamic>{
      'title': instance.title,
      'magnetUrl': instance.magnetUrl,
      'quality': instance.quality,
      'seeders': instance.seeders,
      'leechers': instance.leechers,
      'size': instance.size,
      'source': instance.source,
    };
