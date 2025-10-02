import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/torrent_service.dart';
import 'torrent_state.dart';

class TorrentCubit extends Cubit<TorrentState> {
  final TorrentService _torrentService;

  TorrentCubit({required TorrentService torrentService})
      : _torrentService = torrentService,
        super(const TorrentState.initial());

  /// Загрузить торренты для фильма или сериала
  Future<void> loadTorrents({
    required String imdbId,
    required String mediaType,
    int? season,
  }) async {
    emit(const TorrentState.loading());

    try {
      List<int>? availableSeasons;
      
      // Для сериалов получаем список доступных сезонов
      if (mediaType == 'tv') {
        availableSeasons = await _torrentService.getAvailableSeasons(imdbId);
        
        // Если сезон не указан, выбираем первый доступный
        if (season == null && availableSeasons.isNotEmpty) {
          season = availableSeasons.first;
        }
      }

      // Загружаем торренты
      final torrents = await _torrentService.getTorrents(
        imdbId: imdbId,
        type: mediaType,
        season: season,
      );

      // Группируем торренты по качеству
      final qualityGroups = _torrentService.groupTorrentsByQuality(torrents);

      emit(TorrentState.loaded(
        torrents: torrents,
        qualityGroups: qualityGroups,
        imdbId: imdbId,
        mediaType: mediaType,
        selectedSeason: season,
        availableSeasons: availableSeasons,
      ));
    } catch (e) {
      emit(TorrentState.error(message: e.toString()));
    }
  }

  /// Переключить сезон для сериала
  Future<void> selectSeason(int season) async {
    state.when(
      initial: () {},
      loading: () {},
      error: (_) {},
      loaded: (torrents, qualityGroups, imdbId, mediaType, selectedSeason, availableSeasons, selectedQuality) async {
        emit(const TorrentState.loading());

        try {
          final newTorrents = await _torrentService.getTorrents(
            imdbId: imdbId,
            type: mediaType,
            season: season,
          );

          // Группируем торренты по качеству
          final newQualityGroups = _torrentService.groupTorrentsByQuality(newTorrents);

          emit(TorrentState.loaded(
            torrents: newTorrents,
            qualityGroups: newQualityGroups,
            imdbId: imdbId,
            mediaType: mediaType,
            selectedSeason: season,
            availableSeasons: availableSeasons,
            selectedQuality: null, // Сбрасываем фильтр качества при смене сезона
          ));
        } catch (e) {
          emit(TorrentState.error(message: e.toString()));
        }
      },
    );
  }

  /// Выбрать фильтр по качеству
  void selectQuality(String? quality) {
    state.when(
      initial: () {},
      loading: () {},
      error: (_) {},
      loaded: (torrents, qualityGroups, imdbId, mediaType, selectedSeason, availableSeasons, selectedQuality) {
        emit(TorrentState.loaded(
          torrents: torrents,
          qualityGroups: qualityGroups,
          imdbId: imdbId,
          mediaType: mediaType,
          selectedSeason: selectedSeason,
          availableSeasons: availableSeasons,
          selectedQuality: quality,
        ));
      },
    );
  }

  /// Сбросить состояние
  void reset() {
    emit(const TorrentState.initial());
  }
}
