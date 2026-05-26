import { ChevronDown, Download, Menu, Play } from 'lucide-react-native';
import { Dispatch, SetStateAction } from 'react';
import { Pressable, View } from 'react-native';

import { MediaImage } from '@/components/cards/media-image';
import { RatingsRow } from '@/components/media/ratings-row';
import { ThemedText } from '@/components/themed-text';
import { CollapsEpisode, CollapsCatalogSeries, CollapsSeason, getCollapsWatchProgress } from '@/native/collaps-parser';
import { createMediaDetailsStyles } from '@/styles/media-details.styles';

type ThemePalette = {
  text: string;
  textSecondary: string;
  border: string;
  backgroundElement: string;
};

type EpisodeMeta = {
  overview?: string;
  name?: string;
  tmdbRating?: number | null;
  imdbRating?: number | null;
};

type SeriesEpisodesSectionProps = {
  copy: {
    watchSelector: {
      episodes: string;
      seasons: string;
    };
  };
  theme: ThemePalette;
  styles: ReturnType<typeof createMediaDetailsStyles>;
  detailsId: string;
  detailsDescription: string;
  mediaIdNumber: number;
  canReadProgress: boolean;
  posterUri: string | null;
  selectedSeasonData: CollapsSeason;
  seriesCatalog: CollapsCatalogSeries;
  isSeasonPickerExpanded: boolean;
  setSeasonPickerExpanded: Dispatch<SetStateAction<boolean>>;
  setSelectedSeason: (season: number) => void;
  sortedEpisodes: CollapsEpisode[];
  episodeMetaMap: Record<string, EpisodeMeta>;
  resolveEpisodeStillUrl: (movieId?: string | null, season?: number, episode?: number, size?: 'small' | 'large') => string | null;
  onOpenEpisode: (season: number, episode: number) => void;
};

export function SeriesEpisodesSection(props: SeriesEpisodesSectionProps) {
  const {
    copy,
    theme,
    styles,
    detailsId,
    detailsDescription,
    mediaIdNumber,
    canReadProgress,
    posterUri,
    selectedSeasonData,
    seriesCatalog,
    isSeasonPickerExpanded,
    setSeasonPickerExpanded,
    setSelectedSeason,
    sortedEpisodes,
    episodeMetaMap,
    resolveEpisodeStillUrl,
    onOpenEpisode,
  } = props;

  return (
    <>
      <ThemedText style={styles.sectionTitle}>{copy.watchSelector.episodes}</ThemedText>

      <View style={styles.seasonSelectorWrapper}>
        <Pressable
          style={styles.seasonsHeader}
          onPress={() => setSeasonPickerExpanded((prev: boolean) => !prev)}>
          <View style={styles.seasonsHeaderLeft}>
            <Menu size={18} color={theme.text} />
            <ThemedText style={styles.seasonsHeaderLabel}>Season {selectedSeasonData.season}</ThemedText>
          </View>
          <View style={styles.seasonsHeaderLeft}>
            <ThemedText style={styles.seasonMeta}>
              {seriesCatalog.seasons.length} {copy.watchSelector.seasons}, {selectedSeasonData.episodes.length} {copy.watchSelector.episodes}
            </ThemedText>
            <ChevronDown size={16} color={theme.textSecondary} />
          </View>
        </Pressable>

        {isSeasonPickerExpanded ? (
          <View style={styles.seasonDropdownList}>
            {seriesCatalog.seasons
              .slice()
              .sort((a, b) => a.season - b.season)
              .map((season) => (
                <Pressable
                  key={`season-${season.season}`}
                  style={[styles.seasonOptionRow, season.season === selectedSeasonData.season ? styles.seasonOptionRowActive : null]}
                  onPress={() => {
                    setSelectedSeason(season.season);
                    setSeasonPickerExpanded(false);
                  }}>
                  <ThemedText style={styles.seasonOptionText}>Season {season.season}</ThemedText>
                  {season.season === selectedSeasonData.season ? <ThemedText style={styles.seasonOptionCheck}>✓</ThemedText> : null}
                </Pressable>
              ))}
          </View>
        ) : null}
      </View>

      <View style={styles.episodesList}>
        {sortedEpisodes.map((episode) => {
          const key = `${episode.season}-${episode.episode}`;
          const meta = episodeMetaMap[key];
          const episodeProgress = canReadProgress
            ? getCollapsWatchProgress(mediaIdNumber, episode.season, episode.episode)
            : null;
          const progress = Math.max(0, Math.min(episodeProgress?.progressPercent ?? 0, 100));
          const stillUri = resolveEpisodeStillUrl(detailsId, episode.season, episode.episode, 'small');

          return (
            <Pressable key={`episode-${key}`} style={styles.episodeCard} onPress={() => onOpenEpisode(episode.season, episode.episode)}>
              <View style={styles.episodeContent}>
                <View style={styles.episodeImageWrapper}>
                  <MediaImage primaryUri={stillUri} fallbackUris={[posterUri]} style={styles.episodeImage} />
                  <Pressable style={styles.episodePlayButton} onPress={() => onOpenEpisode(episode.season, episode.episode)}>
                    <Play size={14} strokeWidth={2.5} color="#FFFFFF" fill="#FFFFFF" />
                  </Pressable>
                  {episodeProgress?.watched ? (
                    <View style={styles.episodeWatchedBadge}>
                      <ThemedText style={styles.episodeWatchedText}>✓</ThemedText>
                    </View>
                  ) : progress > 5 ? (
                    <View style={styles.episodeProgressBadge}>
                      <ThemedText style={styles.episodeProgressText}>{Math.round(progress)}%</ThemedText>
                    </View>
                  ) : null}
                  <View style={styles.episodeProgressTrack}>
                    <View
                      style={[
                        styles.episodeProgressFill,
                        {
                          width: progress > 0 ? `${progress}%` : 0,
                        },
                      ]}
                    />
                  </View>
                </View>
                <View style={styles.episodeInfo}>
                  <ThemedText style={styles.episodeTitle} numberOfLines={1}>
                    {episode.episode}. {meta?.name || episode.title || `Episode ${episode.episode}`}
                  </ThemedText>
                  <View style={styles.episodeMetaRow}>
                    <ThemedText style={styles.episodeMeta}>{`S${episode.season} · E${episode.episode}`}</ThemedText>
                    {(meta?.tmdbRating || meta?.imdbRating) ? (
                      <RatingsRow theme={theme} tmdb={meta?.tmdbRating} imdb={meta?.imdbRating} compact />
                    ) : null}
                  </View>
                  <ThemedText style={styles.episodeDescription} numberOfLines={2}>
                    {meta?.overview || detailsDescription}
                  </ThemedText>
                </View>
                <View style={styles.episodeActionsRail}>
                  <Pressable style={styles.episodeActionButton}>
                    <Download size={13} strokeWidth={2.2} color={theme.text} />
                  </Pressable>
                </View>
              </View>
            </Pressable>
          );
        })}
      </View>
    </>
  );
}
