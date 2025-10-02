import 'package:json_annotation/json_annotation.dart';

part 'torrent_item.g.dart';

@JsonSerializable()
class TorrentItem {
  final String? title;
  final String? magnetUrl;
  final String? quality;
  final int? seeders;
  final int? leechers;
  final String? size;
  final String? source;
  
  TorrentItem({
    this.title,
    this.magnetUrl,
    this.quality,
    this.seeders,
    this.leechers,
    this.size,
    this.source,
  });
  
  factory TorrentItem.fromJson(Map<String, dynamic> json) =>
      _$TorrentItemFromJson(json);
  
  Map<String, dynamic> toJson() => _$TorrentItemToJson(this);
}
