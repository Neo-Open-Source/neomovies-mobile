import 'package:freezed_annotation/freezed_annotation.dart';

part 'torrent.freezed.dart';
part 'torrent.g.dart';

@freezed
class Torrent with _$Torrent {
  const factory Torrent({
    required String magnet,
    String? title,
    String? name,
    String? quality,
    int? seeders,
    @JsonKey(name: 'size_gb') double? sizeGb,
  }) = _Torrent;

  factory Torrent.fromJson(Map<String, dynamic> json) => _$TorrentFromJson(json);
}
