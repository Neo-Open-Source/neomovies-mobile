import { useEffect, useMemo, useState } from 'react';
import * as SecureStore from 'expo-secure-store';

import { useContentSource } from '@/hooks/use-content-source';
import { useWatchProgress } from '@/hooks/use-watch-progress';
import { getProviderEmbedHtml, getTvEpisodeDetails } from '@/lib/neomovies-api';
import { CollapsCatalog, CollapsSeason, fetchAllohaSeriesCatalog, parseCollapsCatalog } from '@/native/collaps-parser';
import { MediaDetails } from '@/types/api';

type EpisodeMeta = {
  overview?: string;
  name?: string;
  tmdbRating?: number | null;
  imdbRating?: number | null;
};

type EpisodeMetaCacheEntry = {
  overview?: string;
  name?: string;
  tmdbRating?: number | null;
  imdbRating?: number | null;
  fetchedAtMs: number;
};

type EpisodeMetaCachePayload = {
  entries: Record<string, EpisodeMetaCacheEntry>;
};

const ALLOHA_PUBLIC_TOKEN = 'ffbd312217e27c4245f2678afe1881';
const EPISODE_META_CACHE_TTL_MS = 1000 * 60 * 60 * 12;
const EPISODE_META_CACHE_PREFIX = 'series_episode_meta_v1';

function episodeMetaCacheKey(mediaId: string, season: number): string {
  return `${EPISODE_META_CACHE_PREFIX}:${mediaId}:s${season}`;
}

async function readEpisodeMetaCache(mediaId: string, season: number): Promise<Record<string, EpisodeMetaCacheEntry>> {
  try {
    const raw = await SecureStore.getItemAsync(episodeMetaCacheKey(mediaId, season));
    if (!raw) return {};
    const parsed = JSON.parse(raw) as EpisodeMetaCachePayload;
    return parsed.entries ?? {};
  } catch {
    return {};
  }
}

async function writeEpisodeMetaCache(mediaId: string, season: number, entries: Record<string, EpisodeMetaCacheEntry>): Promise<void> {
  try {
    await SecureStore.setItemAsync(
      episodeMetaCacheKey(mediaId, season),
      JSON.stringify({ entries } satisfies EpisodeMetaCachePayload)
    );
  } catch {
    // ignore cache write failures
  }
}

async function tryLoadAllohaSeriesCatalog(
  mediaId: string,
  _embedHtml: string,
  _wrapperHtml?: string,
  _iframeSource?: string | null
): Promise<CollapsCatalog | null> {
  const rawId = mediaId.replace(/^kp_/, '');
  if (!rawId) return null;
  return fetchAllohaSeriesCatalog(rawId, ALLOHA_PUBLIC_TOKEN);
}

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
            ? (await (async () => {
                const apiCatalog = await tryLoadAllohaSeriesCatalog(
                  details.id,
                  payload.embedHtml,
                  payload.wrapperHtml,
                  payload.iframeSource
                ).catch((error) => {
                  if (__DEV__) {
                    console.log('[AllohaSeries] api catalog error', {
                      message: error instanceof Error ? error.message : String(error),
                    });
                  }
                  return null;
                });
                return apiCatalog;
              })())
            : await parseCollapsCatalog(payload.embedHtml);
        if (!active) return;
        if (__DEV__) {
          console.log('[SeriesDetails] parsed catalog', {
            source,
            kind: parsed?.kind ?? null,
            seasons: parsed && parsed.kind === 'series' ? parsed.seasons.length : 0,
            episodes:
              parsed && parsed.kind === 'series'
                ? parsed.seasons.reduce((sum, season) => sum + season.episodes.length, 0)
                : 0,
          });
        }
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
    if (!details || !selectedSeasonData || source === 'alloha') return () => {
      active = false;
    };

    const season = selectedSeasonData.season;
    const episodes = selectedSeasonData.episodes.slice();
    const now = Date.now();

    void (async () => {
      const cacheEntries = await readEpisodeMetaCache(details.id, season);
      if (!active) return;

      const cachedMetaPatch: Record<string, EpisodeMeta> = {};
      for (const item of episodes) {
        const key = `${item.season}-${item.episode}`;
        const cache = cacheEntries[key];
        if (!cache) continue;
        cachedMetaPatch[key] = {
          overview: cache.overview,
          name: cache.name,
          tmdbRating: cache.tmdbRating,
          imdbRating: cache.imdbRating,
        };
      }
      if (Object.keys(cachedMetaPatch).length > 0) {
        setEpisodeMetaMap((prev) => ({ ...prev, ...cachedMetaPatch }));
      }

      const queue = episodes.filter((item) => {
        const key = `${item.season}-${item.episode}`;
        const cache = cacheEntries[key];
        if (!cache) return true;
        return now - cache.fetchedAtMs > EPISODE_META_CACHE_TTL_MS;
      });

      if (queue.length === 0) return;

      const nextCacheEntries = { ...cacheEntries };
      const workers = Array.from({ length: Math.min(4, queue.length) }, async () => {
        while (active && queue.length > 0) {
          const item = queue.shift();
          if (!item) return;
          const key = `${item.season}-${item.episode}`;
          try {
            const data = await getTvEpisodeDetails(details.id, item.season, item.episode);
            if (!active) return;
            const nextMeta = {
              overview: data.overview,
              name: data.name,
              tmdbRating: data.ratings?.tmdb,
              imdbRating: data.ratings?.imdb,
            };
            setEpisodeMetaMap((prev) => ({ ...prev, [key]: nextMeta }));
            nextCacheEntries[key] = {
              ...nextMeta,
              fetchedAtMs: Date.now(),
            };
          } catch {
            if (!active) return;
            if (!nextCacheEntries[key]) {
              setEpisodeMetaMap((prev) => ({ ...prev, [key]: {} }));
            }
          }
        }
      });

      await Promise.all(workers);
      if (!active) return;
      await writeEpisodeMetaCache(details.id, season, nextCacheEntries);
    })();

    return () => {
      active = false;
    };
  }, [details, selectedSeasonData, source]);

  const firstEpisode = selectedSeasonData?.episodes[0] ?? null;
  const mediaIdNumber = Number((details?.id ?? '').replace(/^kp_/, ''));
  const canReadProgress = Number.isFinite(mediaIdNumber);

  const progressKpId = details?.type === 'tv' && canReadProgress ? mediaIdNumber : null;
  const seriesProgress = useWatchProgress(progressKpId);

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
