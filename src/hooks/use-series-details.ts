import { useFocusEffect } from 'expo-router';
import { useCallback, useEffect, useMemo, useState } from 'react';
import * as SecureStore from 'expo-secure-store';

import { useContentSource } from '@/hooks/use-content-source';
import { useWatchProgress } from '@/hooks/use-watch-progress';
import { getProviderEmbedHtml, getTvEpisodeDetails } from '@/lib/neomovies-api';
import { CollapsCatalog, CollapsSeason, listCollapsWatchProgressRecords, parseCollapsCatalog } from '@/native/collaps-parser';
import { MediaDetails } from '@/types/api';
import { buildAllohaSeriesCatalogFromApi } from '@/hooks/watch-player/alloha';

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

const EPISODE_META_CACHE_TTL_MS = 1000 * 60 * 60 * 12;
const EPISODE_META_CACHE_PREFIX = 'series_episode_meta_v1';
const PRIORITY_EPISODE_META_PREFETCH = 6;
const EPISODE_META_FETCH_CONCURRENCY = 2;
const BACKGROUND_EPISODE_META_FETCH_CONCURRENCY = 1;
const BACKGROUND_EPISODE_META_DELAY_MS = 350;
const BACKGROUND_EPISODE_META_BATCH_SIZE = 2;

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

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

export function useSeriesDetails(details: MediaDetails | null) {
  const { source, ready: sourceReady } = useContentSource();
  const [catalog, setCatalog] = useState<CollapsCatalog | null>(null);
  const [selectedSeason, setSelectedSeason] = useState(1);
  const [isSeasonPickerExpanded, setSeasonPickerExpanded] = useState(false);
  const [episodeMetaMap, setEpisodeMetaMap] = useState<Record<string, EpisodeMeta>>({});
  const [seasonProgressMap, setSeasonProgressMap] = useState<Record<string, number>>({});
  const mediaIdNumber = Number((details?.id ?? '').replace(/^kp_/, ''));
  const canReadProgress = Number.isFinite(mediaIdNumber);

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
        if (!sourceReady) return;
        const parsed =
          source === 'alloha'
            ? (await (async () => {
                const apiCatalog = await buildAllohaSeriesCatalogFromApi(details.id).catch((error) => {
                  if (__DEV__) {
                    console.log('[AllohaSeries] api catalog error', {
                      message: error instanceof Error ? error.message : String(error),
                    });
                  }
                  return null;
                });
                return apiCatalog;
              })())
            : await (async () => {
                const payload = await getProviderEmbedHtml(details.id, source);
                return parseCollapsCatalog(payload.embedHtml);
              })();
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
  }, [details, source, sourceReady]);

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

      const pendingEpisodes = episodes.filter((item) => {
        const key = `${item.season}-${item.episode}`;
        const cache = cacheEntries[key];
        if (!cache) return true;
        return now - cache.fetchedAtMs > EPISODE_META_CACHE_TTL_MS;
      });

      if (pendingEpisodes.length === 0) return;

      const priorityQueue = pendingEpisodes.slice(0, PRIORITY_EPISODE_META_PREFETCH);
      const backgroundQueue = pendingEpisodes.slice(PRIORITY_EPISODE_META_PREFETCH);

      const nextCacheEntries = { ...cacheEntries };

      const fetchEpisodeMeta = async (item: typeof pendingEpisodes[number]) => {
        const key = `${item.season}-${item.episode}`;
        try {
          const data = await getTvEpisodeDetails(details.id, item.season, item.episode);
          if (!active) return null;
          const nextMeta = {
            overview: data.overview,
            name: data.name,
            tmdbRating: data.ratings?.tmdb,
            imdbRating: data.ratings?.imdb,
          };
          nextCacheEntries[key] = {
            ...nextMeta,
            fetchedAtMs: Date.now(),
          };
          return { key, meta: nextMeta };
        } catch {
          if (!active) return null;
          if (!nextCacheEntries[key]) {
            return { key, meta: {} };
          }
          return null;
        }
      };

      const runQueue = async (
        queue: typeof pendingEpisodes,
        concurrency: number,
        delayMs = 0
      ) => {
        const patch: Record<string, EpisodeMeta> = {};
        const workers = Array.from({ length: Math.min(concurrency, queue.length) }, async () => {
          while (active && queue.length > 0) {
            const item = queue.shift();
            if (!item) return;
            if (delayMs > 0) {
              await sleep(delayMs);
              if (!active) return;
            }
            const result = await fetchEpisodeMeta(item);
            if (result) {
              patch[result.key] = result.meta;
            }
          }
        });
        await Promise.all(workers);
        return patch;
      };

      const priorityPatch = await runQueue(priorityQueue, EPISODE_META_FETCH_CONCURRENCY);
      if (!active) return;
      if (Object.keys(priorityPatch).length > 0) {
        setEpisodeMetaMap((prev) => ({ ...prev, ...priorityPatch }));
      }
      await writeEpisodeMetaCache(details.id, season, nextCacheEntries);

      if (backgroundQueue.length > 0) {
        void (async () => {
          const queue = [...backgroundQueue];
          while (active && queue.length > 0) {
            const chunk = queue.splice(0, BACKGROUND_EPISODE_META_BATCH_SIZE);
            const patch = await runQueue(
              chunk,
              BACKGROUND_EPISODE_META_FETCH_CONCURRENCY,
              BACKGROUND_EPISODE_META_DELAY_MS
            );
            if (!active) return;
            if (Object.keys(patch).length > 0) {
              setEpisodeMetaMap((prev) => ({ ...prev, ...patch }));
              await writeEpisodeMetaCache(details.id, season, nextCacheEntries);
            }
          }
        })();
      }
    })();

    return () => {
      active = false;
    };
  }, [details, selectedSeasonData, source]);

  useFocusEffect(
    useCallback(() => {
      if (!details || details.type !== 'tv' || !Number.isFinite(mediaIdNumber)) {
        setSeasonProgressMap({});
        return;
      }

      const records = listCollapsWatchProgressRecords(mediaIdNumber);
      const nextMap: Record<string, number> = {};
      for (const record of records) {
        if (record.season == null || record.episode == null) continue;
        nextMap[`${record.season}-${record.episode}`] = Math.max(0, Math.min(record.progressPercent ?? 0, 100));
      }
      setSeasonProgressMap(nextMap);
    }, [details, mediaIdNumber])
  );

  const firstEpisode = selectedSeasonData?.episodes[0] ?? null;
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
    seasonProgressMap,
    sortedEpisodes,
  };
}
