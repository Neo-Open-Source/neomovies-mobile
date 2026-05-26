import { useEffect, useMemo, useState } from 'react';

import { useContentSource } from '@/hooks/use-content-source';
import { getProviderEmbedHtml, getTvEpisodeDetails } from '@/lib/neomovies-api';
import { CollapsCatalog, CollapsSeason, getCollapsWatchProgress, parseAllohaRuntimePayload, parseCollapsCatalog } from '@/native/collaps-parser';
import { MediaDetails } from '@/types/api';

type EpisodeMeta = {
  overview?: string;
  name?: string;
  tmdbRating?: number | null;
  imdbRating?: number | null;
};

export function useSeriesDetails(details: MediaDetails | null) {
  const { source } = useContentSource();
  const [catalog, setCatalog] = useState<CollapsCatalog | null>(null);
  const [selectedSeason, setSelectedSeason] = useState(1);
  const [isSeasonPickerExpanded, setSeasonPickerExpanded] = useState(false);
  const [episodeMetaMap, setEpisodeMetaMap] = useState<Record<string, EpisodeMeta>>({});

  useEffect(() => {
    let active = true;
    if (!details || details.type !== 'tv') {
      setCatalog(null);
      return () => {
        active = false;
      };
    }
    void (async () => {
      try {
        const payload = await getProviderEmbedHtml(details.id, source);
        const parsed =
          source === 'alloha'
            ? (() => {
                const runtime = parseAllohaRuntimePayload(payload.embedHtml, payload.embedOrigin, {
                  Referer: payload.embedReferer,
                  Origin: payload.embedOrigin,
                });
                const url = runtime.videoURL ?? '';
                if (!url) return null;
                return {
                  kind: 'series' as const,
                  source: 'alloha',
                  seasons: [
                    {
                      season: 1,
                      title: 'Season 1',
                      episodes: [
                        {
                          season: 1,
                          episode: 1,
                          title: 'Episode 1',
                          playlist: {
                            primaryUrl: url,
                            hlsUrl: url.includes('.m3u8') ? url : null,
                            dashUrl: url.includes('.mpd') ? url : null,
                            voiceovers: [],
                            subtitles: [],
                          },
                        },
                      ],
                    },
                  ],
                } as CollapsCatalog;
              })()
            : await parseCollapsCatalog(payload.embedHtml);
        if (!active) return;
        setCatalog(parsed);
      } catch {
        if (!active) return;
        setCatalog(null);
      }
    })();
    return () => {
      active = false;
    };
  }, [details, source]);

  const seriesCatalog = catalog?.kind === 'series' ? catalog : null;
  const selectedSeasonData: CollapsSeason | null =
    seriesCatalog?.seasons.find((season) => season.season === selectedSeason) ??
    seriesCatalog?.seasons[0] ??
    null;

  useEffect(() => {
    if (!selectedSeasonData?.season) return;
    setSelectedSeason(selectedSeasonData.season);
  }, [selectedSeasonData?.season]);

  useEffect(() => {
    let active = true;
    if (!details || !selectedSeasonData) return () => {
      active = false;
    };

    void Promise.all(
      selectedSeasonData.episodes.map(async (item) => {
        try {
          const data = await getTvEpisodeDetails(details.id, item.season, item.episode);
          return {
            key: `${item.season}-${item.episode}`,
            value: {
              overview: data.overview,
              name: data.name,
              tmdbRating: data.ratings?.tmdb,
              imdbRating: data.ratings?.imdb,
            },
          };
        } catch {
          return {
            key: `${item.season}-${item.episode}`,
            value: {},
          };
        }
      })
    ).then((entries) => {
      if (!active) return;
      setEpisodeMetaMap((prev) => {
        const next = { ...prev };
        for (const entry of entries) next[entry.key] = entry.value;
        return next;
      });
    });

    return () => {
      active = false;
    };
  }, [details, selectedSeasonData]);

  const firstEpisode = selectedSeasonData?.episodes[0] ?? null;
  const mediaIdNumber = Number((details?.id ?? '').replace(/^kp_/, ''));
  const canReadProgress = Number.isFinite(mediaIdNumber);

  const seriesProgress =
    details?.type === 'tv' && canReadProgress
      ? getCollapsWatchProgress(mediaIdNumber, null, null)
      : null;

  const sortedEpisodes = useMemo(
    () => selectedSeasonData?.episodes.slice().sort((a, b) => a.episode - b.episode) ?? [],
    [selectedSeasonData]
  );

  return {
    seriesCatalog,
    selectedSeasonData,
    selectedSeason,
    setSelectedSeason,
    isSeasonPickerExpanded,
    setSeasonPickerExpanded,
    episodeMetaMap,
    firstEpisode,
    mediaIdNumber,
    canReadProgress,
    seriesProgress,
    sortedEpisodes,
  };
}
