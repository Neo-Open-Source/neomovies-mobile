import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, Platform, View } from 'react-native';
import * as Device from 'expo-device';

const ExpoFileSystem = require('expo-file-system') as {
  File: new (...args: unknown[]) => {
    uri: string;
    create: (options?: { overwrite?: boolean; intermediates?: boolean }) => void;
    write: (content: string) => void;
  };
  Paths: { cache: unknown };
};

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useContentSource } from '@/hooks/use-content-source';
import { API_ORIGIN } from '@/lib/config';
import {
  addAVPlayerEpisodeChangedListener,
  addAVPlayerProgressListener,
  avPlayerConfigurePlaylist,
  avPlayerPresentNativeUI,
  avPlayerSelectEpisode,
  collapsDashContainsAv1,
  collapsDeviceSupportsAv1,
  CollapsCatalog,
  CollapsEpisode,
  CollapsSeason,
  CollapsSubtitle,
  parseAllohaRuntimePayload,
  parseCollapsCatalog,
} from '@/native/collaps-parser';
import CollapsParser from 'neomovies-core';
import { getProviderEmbedHtml } from '@/lib/neomovies-api';
import { createWatchSelectorStyles } from '@/styles/watch-selector.styles';

type PlayerHeaders = {
  Referer: string;
  Origin: string;
};

function isKnownAv1BrokenDevice(): boolean {
  if (Platform.OS !== 'android') return false;
  const brand = (Device.brand ?? '').toLowerCase();
  const manufacturer = (Device.manufacturer ?? '').toLowerCase();
  const model = (Device.modelName ?? '').toLowerCase();
  const designName = (String((Platform as any).constants?.Model ?? '')).toLowerCase();

  const isXiaomiFamily =
    brand.includes('xiaomi') ||
    brand.includes('redmi') ||
    brand.includes('poco') ||
    manufacturer.includes('xiaomi');

  const knownBadModel =
    model.includes('220333qpg') ||
    designName.includes('220333qpg') ||
    designName.includes('frost');

  return isXiaomiFamily && knownBadModel;
}

function findSeasonByNumber(seasons: CollapsSeason[], season: number) {
  return seasons.find((item) => item.season === season) ?? seasons[0] ?? null;
}

function findEpisodeByNumber(episodes: CollapsEpisode[], episode: number) {
  return episodes.find((item) => item.episode === episode) ?? episodes[0] ?? null;
}

function normalizeMediaFileId(value: string | undefined, fallback: string): string {
  const safe = (value ?? fallback).toString().trim();
  return safe.replace(/[^a-zA-Z0-9_-]/g, "_") || fallback;
}

function absolutizeHlsManifestUris(manifest: string, manifestUrl: string): string {
  const lines = manifest.split(/\r?\n/);
  const absolutized = lines.map((line) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return line;
    try {
      return new URL(trimmed, manifestUrl).toString();
    } catch {
      return line;
    }
  });
  return absolutized.join('\n');
}

async function rewriteHlsToLocalOrFallback(
  hlsUrl: string,
  voices: string[],
  subtitles: CollapsSubtitle[],
  mediaFileId: string,
  headers: PlayerHeaders
): Promise<string> {
  try {
    const rewrittenHls = await CollapsParser.rewriteCollapsHlsFromUrl(
      hlsUrl,
      voices,
      subtitles,
      mediaFileId,
      headers.Referer,
      headers.Origin
    );
    const finalHls = absolutizeHlsManifestUris(rewrittenHls, hlsUrl);
    const file = new ExpoFileSystem.File(ExpoFileSystem.Paths.cache, `${mediaFileId}.m3u8`);
    file.create({ overwrite: true, intermediates: true });
    file.write(finalHls);
    return file.uri;
  } catch (error) {
    console.warn('[CollapsNative] rewrite HLS failed, fallback to source URL', {
      hlsUrl,
      mediaFileId,
      error: error instanceof Error ? error.message : String(error),
    });
    return hlsUrl;
  }
}

async function rewriteDashToLocalOrFallback(
  dashUrl: string,
  voices: string[],
  subtitles: CollapsSubtitle[],
  mediaFileId: string,
  headers: PlayerHeaders
): Promise<string | null> {
  try {
    const rewrittenDash = await CollapsParser.rewriteCollapsDashFromUrl(
      dashUrl,
      voices,
      subtitles,
      mediaFileId,
      headers.Referer,
      headers.Origin
    );
    const file = new ExpoFileSystem.File(ExpoFileSystem.Paths.cache, `${mediaFileId}.mpd`);
    file.create({ overwrite: true, intermediates: true });
    file.write(rewrittenDash);
    return file.uri;
  } catch (error) {
    console.warn('[CollapsNative] rewrite DASH failed, fallback to source URL', {
      dashUrl,
      mediaFileId,
      error: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
}

async function shouldPreferHlsForAndroidExo(
  hlsUrl: string | null,
  dashUrl: string | null,
  headers: PlayerHeaders
): Promise<boolean> {
  if (!hlsUrl) return false;
  if (!dashUrl) return true;
  if (Platform.OS !== 'android') return true;
  try {
    const containsAv1 = await collapsDashContainsAv1(dashUrl, {
      referer: headers.Referer,
      origin: headers.Origin,
    });
    if (!containsAv1) return false;

    const supportsAv1 = collapsDeviceSupportsAv1();
    const forceHlsForBrokenAv1 = !supportsAv1;
    console.log('[CollapsNative] shouldPreferHlsForAndroidExo:av1Probe', {
      dashUrl,
      containsAv1,
      supportsAv1,
      forceHlsForBrokenAv1,
    });

    if (forceHlsForBrokenAv1 && hlsUrl) {
      return true;
    }

    // If device doesn't support AV1, prefer HLS to avoid black-screen AV1 paths.
    // On AV1-capable devices keep DASH and let Exo auto-select representations.
    return false;
  } catch (error) {
    console.warn('[CollapsNative] collapsDashContainsAv1 failed, fallback to HLS', {
      dashUrl,
      error: error instanceof Error ? error.message : String(error),
    });
    return true;
  }
}

export default function WatchPlayerScreen() {
  const params = useLocalSearchParams<{
    id?: string;
    title?: string;
    embed_html?: string;
    season?: string;
    episode?: string;
  }>();
  const { source } = useContentSource();

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const initialSeason = Number(params.season ?? '1') || 1;
  const initialEpisode = Number(params.episode ?? '1') || 1;

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    void (async () => {
      try {
        const mediaId = params.id ?? '';
        if (!mediaId) {
          throw new Error('Missing media id');
        }

        const payload = await getProviderEmbedHtml(mediaId, source, initialSeason, initialEpisode);
        const embedHtml = payload.embedHtml;
        const playbackHeaders: PlayerHeaders = {
          Referer: payload.embedReferer,
          Origin: payload.embedOrigin,
        };
        const catalog =
          source === 'alloha'
            ? (() => {
                const parsed = parseAllohaRuntimePayload(embedHtml, playbackHeaders.Origin, playbackHeaders);
                const primaryUrl = parsed.videoURL ?? '';
                const subtitles = parsed.subtitles ?? [];
                if (!primaryUrl) {
                  return {
                    kind: 'movie' as const,
                    source: 'alloha',
                    playlist: {
                      primaryUrl: '',
                      hlsUrl: null,
                      dashUrl: null,
                      voiceovers: [],
                      subtitles: [],
                    },
                  };
                }
                if (params.season || params.episode) {
                  return {
                    kind: 'series' as const,
                    source: 'alloha',
                    seasons: [
                      {
                        season: initialSeason,
                        title: `Season ${initialSeason}`,
                        episodes: [
                          {
                            season: initialSeason,
                            episode: initialEpisode,
                            title: `Episode ${initialEpisode}`,
                            playlist: {
                              primaryUrl,
                              hlsUrl: primaryUrl.includes('.m3u8') ? primaryUrl : null,
                              dashUrl: primaryUrl.includes('.mpd') ? primaryUrl : null,
                              voiceovers: [],
                              subtitles,
                            },
                          },
                        ],
                      },
                    ],
                  };
                }
                return {
                  kind: 'movie' as const,
                  source: 'alloha',
                  playlist: {
                    primaryUrl,
                    hlsUrl: primaryUrl.includes('.m3u8') ? primaryUrl : null,
                    dashUrl: primaryUrl.includes('.mpd') ? primaryUrl : null,
                    voiceovers: [],
                    subtitles,
                  },
                };
              })()
            : await parseCollapsCatalog(embedHtml);

        if (cancelled) return;

        console.log('[WatchScreen] Launching player', {
          kind: catalog.kind,
          id: params.id,
          title: params.title,
          season: initialSeason,
          episode: initialEpisode,
        });

        // Автоматически запускаем плеер
        if (catalog.kind === 'movie') {
          await launchMoviePlayer(catalog, playbackHeaders, params.title ?? null, params.id ?? 'movie');
        } else if (catalog.kind === 'series') {
          await launchSeriesPlayer(catalog, playbackHeaders, params.title ?? null, params.id ?? 'series', initialSeason, initialEpisode);
        }

        console.log('[WatchScreen] Player launched, navigating back');

        // Возвращаемся назад после запуска плеера
        if (!cancelled && router.canGoBack()) {
          router.back();
        }
      } catch (reason) {
        if (cancelled) return;
        setError(reason instanceof Error ? reason.message : 'Request failed');
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [params.id, params.season, params.episode, initialSeason, initialEpisode, source, params.title]);


  return (
    <ThemedView style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
      {loading ? (
        <ActivityIndicator size="large" />
      ) : error ? (
        <ThemedText style={{ color: 'red', padding: 20, textAlign: 'center' }}>{error}</ThemedText>
      ) : null}
    </ThemedView>
  );
}

async function launchMoviePlayer(
  catalog: CollapsCatalog & { kind: 'movie' },
  playbackHeaders: PlayerHeaders,
  title: string | null,
  mediaId: string
) {
  if (Platform.OS === 'ios') {
    const url = catalog.playlist.hlsUrl ?? catalog.playlist.dashUrl ?? catalog.playlist.primaryUrl;
    if (!url) return;
    await avPlayerConfigurePlaylist(
      [
        {
          mediaId: mediaId ?? url,
          title: title ?? '',
          url,
          headers: {
            Referer: playbackHeaders.Referer,
            Origin: playbackHeaders.Origin,
          },
          voiceovers: catalog.playlist.voiceovers,
          subtitles: catalog.playlist.subtitles,
        },
      ],
      0,
      true
    );
    await avPlayerPresentNativeUI();
    return;
  }

  // Android ExoPlayer
  const hlsUrl = catalog.playlist.hlsUrl;
  const dashUrl = catalog.playlist.dashUrl;
  const primaryUrl = catalog.playlist.primaryUrl;
  const preferHls = await shouldPreferHlsForAndroidExo(hlsUrl, dashUrl, playbackHeaders);

  let finalUrl: string;
  const mediaFileId = normalizeMediaFileId(mediaId, 'movie');

  if (preferHls && hlsUrl) {
    finalUrl = await rewriteHlsToLocalOrFallback(
      hlsUrl,
      catalog.playlist.voiceovers,
      catalog.playlist.subtitles,
      mediaFileId,
      playbackHeaders
    );
  } else if (dashUrl) {
    const dashLocalOrNull = await rewriteDashToLocalOrFallback(
      dashUrl,
      catalog.playlist.voiceovers,
      catalog.playlist.subtitles,
      mediaFileId,
      playbackHeaders
    );
    if (dashLocalOrNull) {
      finalUrl = dashLocalOrNull;
    } else if (hlsUrl) {
      finalUrl = await rewriteHlsToLocalOrFallback(
        hlsUrl,
        catalog.playlist.voiceovers,
        catalog.playlist.subtitles,
        mediaFileId,
        playbackHeaders
      );
    } else {
      finalUrl = dashUrl;
    }
  } else {
    finalUrl = primaryUrl;
  }

  if (!finalUrl) return;

  const kpId = Number(mediaId.replace(/^kp_/, ''));
  await CollapsParser.exoPlayerLaunch?.(finalUrl, playbackHeaders, title, Number.isFinite(kpId) ? kpId : null);
}

async function launchSeriesPlayer(
  catalog: CollapsCatalog & { kind: 'series' },
  playbackHeaders: PlayerHeaders,
  title: string | null,
  mediaId: string,
  initialSeason: number,
  initialEpisode: number
) {
  const activeSeason = findSeasonByNumber(catalog.seasons, initialSeason);
  if (!activeSeason) return;

  const activeEpisode = findEpisodeByNumber(activeSeason.episodes, initialEpisode);
  if (!activeEpisode) return;

  if (Platform.OS === 'ios') {
    const playlistItems = catalog.seasons
      .flatMap((season) =>
        season.episodes.map((episode) => ({
          mediaId: `${mediaId}_s${season.season}_e${episode.episode}`,
          title: title ?? 'Series',
          url: episode.playlist.primaryUrl || episode.playlist.hlsUrl || episode.playlist.dashUrl,
          headers: {
            Referer: playbackHeaders.Referer,
            Origin: playbackHeaders.Origin,
          },
          season: season.season,
          episode: episode.episode,
          voiceovers: episode.playlist.voiceovers,
          subtitles: episode.playlist.subtitles,
        }))
      )
      .filter((item) => Boolean(item.url));

    const startIndex = Math.max(
      0,
      playlistItems.findIndex((item) => item.season === initialSeason && item.episode === initialEpisode)
    );

    const kpId = Number(mediaId.replace(/^kp_/, ''));
    
    console.log('[iOS Player] Configuring playlist', {
      totalItems: playlistItems.length,
      startIndex,
      kpId: Number.isFinite(kpId) ? kpId : null,
      firstUrl: playlistItems[0]?.url?.substring(0, 100),
      targetEpisode: `S${initialSeason}E${initialEpisode}`,
    });
    
    await avPlayerConfigurePlaylist(playlistItems, startIndex, true, Number.isFinite(kpId) ? kpId : null);
    await avPlayerPresentNativeUI();
    return;
  }

  // Android ExoPlayer
  const hlsUrl = activeEpisode.playlist.hlsUrl;
  const dashUrl = activeEpisode.playlist.dashUrl;
  const primaryUrl = activeEpisode.playlist.primaryUrl;
  const seriesBaseId = normalizeMediaFileId(mediaId, 'series');
  const episodeMediaId = `${seriesBaseId}_${activeEpisode.season}_${activeEpisode.episode}`;
  const preferHls = await shouldPreferHlsForAndroidExo(hlsUrl, dashUrl, playbackHeaders);

  const seasonPlaylist = catalog.seasons
    .sort((a, b) => a.season - b.season)
    .flatMap((season) =>
      season.episodes
        .sort((a, b) => a.episode - b.episode)
        .map((episode) => ({
          season: season.season,
          episode: episode.episode,
          url: preferHls
            ? (episode.playlist.hlsUrl ?? episode.playlist.dashUrl ?? episode.playlist.primaryUrl)
            : (episode.playlist.dashUrl ?? episode.playlist.hlsUrl ?? episode.playlist.primaryUrl),
          name: `${title ?? 'Series'}_S${String(season.season).padStart(2, '0')}E${String(episode.episode).padStart(2, '0')}`,
        }))
        .filter((item) => Boolean(item.url))
    );

  const startIndex = Math.max(
    0,
    seasonPlaylist.findIndex((item) => item.season === activeEpisode.season && item.episode === activeEpisode.episode)
  );

  const kpId = Number(mediaId.replace(/^kp_/, ''));
  if (CollapsParser.exoPlayerLaunchPlaylist && seasonPlaylist.length > 0) {
    await CollapsParser.exoPlayerLaunchPlaylist(
      seasonPlaylist.map((item) => item.url),
      startIndex,
      playbackHeaders,
      seasonPlaylist.map((item) => item.name),
      title,
      activeEpisode.playlist.voiceovers,
      Number.isFinite(kpId) ? kpId : null
    );
  }
}

