import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../data/models/torrent.dart';

part 'torrent_state.freezed.dart';

@freezed
class TorrentState with _$TorrentState {
  const factory TorrentState.initial() = _Initial;
  
  const factory TorrentState.loading() = _Loading;
  
  const factory TorrentState.loaded({
    required List<Torrent> torrents,
    required Map<String, List<Torrent>> qualityGroups,
    required String imdbId,
    required String mediaType,
    int? selectedSeason,
    List<int>? availableSeasons,
    String? selectedQuality, // Фильтр по качеству
  }) = _Loaded;
  
  const factory TorrentState.error({
    required String message,
  }) = _Error;
}
