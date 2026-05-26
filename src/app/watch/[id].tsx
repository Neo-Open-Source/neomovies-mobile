import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, Platform, StyleSheet, View } from 'react-native';
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
  fetchAllohaSeriesCatalog,
  parseCollapsCatalog,
  resolveAllohaPlayableFromIframe,
} from '@/native/collaps-parser';
import CollapsParser from 'neomovies-core';
import { getProviderEmbedHtml } from '@/lib/neomovies-api';

type PlayerHeaders = {
  Referer: string;
  Origin: string;
};

const ALLOHA_PUBLIC_TOKEN = 'ffbd312217e27c4245f2678afe1881';

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

async function buildAllohaSeriesCatalogFromApi(mediaId: string): Promise<CollapsCatalog | null> {
  const rawId = mediaId.replace(/^kp_/, '');
  if (!rawId) return null;
  return fetchAllohaSeriesCatalog(rawId, ALLOHA_PUBLIC_TOKEN);
}

async function resolveAllohaIframeToPlayable(
  iframeUrl: string,
  _headers: PlayerHeaders
): Promise<{ url: string; subtitles: CollapsSubtitle[] }> {
  return resolveAllohaPlayableFromIframe(iframeUrl);
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
            ? (await buildAllohaSeriesCatalogFromApi(mediaId))
            : await parseCollapsCatalog(embedHtml);
        if (!catalog) {
          throw new Error('Failed to parse provider catalog');
        }

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
    <ThemedView style={styles.container}>
      {loading ? (
        <ActivityIndicator size="large" />
      ) : error ? (
        <ThemedText style={styles.errorText}>{error}</ThemedText>
      ) : null}
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  errorText: {
    color: 'red',
    padding: 20,
    textAlign: 'center',
  },
});

async function launchMoviePlayer(
  catalog: CollapsCatalog & { kind: 'movie' },
  playbackHeaders: PlayerHeaders,
  title: string | null,
  mediaId: string
) {
  if (Platform.OS === 'ios') {
    const kpId = Number(mediaId.replace(/^kp_/, ''));
    const allohaVariants = catalog.allohaVariants;
    const headers = { Referer: playbackHeaders.Referer, Origin: playbackHeaders.Origin };

    const playlistItems = allohaVariants && allohaVariants.length > 1
      ? allohaVariants.map((variant) => ({
          mediaId: mediaId,
          title: variant.title || title || '',
          url: variant.url,
          headers,
          voiceovers: [],
          subtitles: catalog.playlist.subtitles,
        }))
      : (() => {
          const url = catalog.playlist.hlsUrl ?? catalog.playlist.dashUrl ?? catalog.playlist.primaryUrl;
          if (!url) return null;
          return [{ mediaId: mediaId ?? url, title: title ?? '', url, headers, voiceovers: catalog.playlist.voiceovers, subtitles: catalog.playlist.subtitles }];
        })();

    if (!playlistItems) return;
    await avPlayerConfigurePlaylist(playlistItems, 0, true, Number.isFinite(kpId) ? kpId : null);
    await avPlayerPresentNativeUI();
    return;
  }

  // Android ExoPlayer
  const kpId = Number(mediaId.replace(/^kp_/, ''));
  const allohaVariants = catalog.allohaVariants;

  // For Alloha with multiple audio variants: launch a playlist where each item = one dubbing.
  if (allohaVariants && allohaVariants.length > 1 && CollapsParser.exoPlayerLaunchPlaylist) {
    await CollapsParser.exoPlayerLaunchPlaylist(
      allohaVariants.map((v) => v.url),
      0,
      playbackHeaders,
      allohaVariants.map((v) => v.title || title || ''),
      title,
      [],
      Number.isFinite(kpId) ? kpId : null
    );
    return;
  }

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
  if (catalog.source === 'alloha') {
    const activeSeason = findSeasonByNumber(catalog.seasons, initialSeason);
    const activeEpisode = activeSeason ? findEpisodeByNumber(activeSeason.episodes, initialEpisode) : null;
    if (!activeEpisode) return;
    const iframeUrl = activeEpisode.playlist.primaryUrl;
    const resolved = await resolveAllohaIframeToPlayable(iframeUrl, playbackHeaders);
    const kpId = Number(mediaId.replace(/^kp_/, ''));
    await CollapsParser.exoPlayerLaunch?.(
      resolved.url,
      playbackHeaders,
      `${title ?? 'Series'} S${activeEpisode.season}E${activeEpisode.episode}`,
      Number.isFinite(kpId) ? kpId : null
    );
    return;
  }

  const activeSeason = findSeasonByNumber(catalog.seasons, initialSeason);
  if (!activeSeason) return;

  const activeEpisode = findEpisodeByNumber(activeSeason.episodes, initialEpisode);
  if (!activeEpisode) return;

  if (Platform.OS === 'ios') {
    const kpId = Number(mediaId.replace(/^kp_/, ''));
    const headers = { Referer: playbackHeaders.Referer, Origin: playbackHeaders.Origin };
    const allohaVariants = catalog.allohaVariants;

    // For Alloha: each audio variant = a different dubbing/voice-over for the current episode.
    // Present them as separate playlist items so the user can switch via prev/next.
    const playlistItems = allohaVariants && allohaVariants.length > 1
      ? allohaVariants.map((variant) => ({
          mediaId: `${mediaId}_s${initialSeason}_e${initialEpisode}`,
          title: variant.title || title || '',
          url: variant.url,
          headers,
          season: initialSeason,
          episode: initialEpisode,
          voiceovers: [],
          subtitles: activeEpisode.playlist.subtitles,
        }))
      : catalog.seasons.flatMap((season) =>
          season.episodes.flatMap((episode) => {
            const url = episode.playlist.primaryUrl || episode.playlist.hlsUrl || episode.playlist.dashUrl;
            if (!url) return [];
            return [
              {
                mediaId: `${mediaId}_s${season.season}_e${episode.episode}`,
                title: title ?? 'Series',
                url,
                headers,
                season: season.season,
                episode: episode.episode,
                voiceovers: episode.playlist.voiceovers,
                subtitles: episode.playlist.subtitles,
              },
            ];
          })
        );

    const startIndex = allohaVariants && allohaVariants.length > 1
      ? 0
      : Math.max(0, playlistItems.findIndex((item) => item.season === initialSeason && item.episode === initialEpisode));

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
  const kpId = Number(mediaId.replace(/^kp_/, ''));
  const allohaVariantsAndroid = catalog.allohaVariants;

  // For Alloha with multiple audio variants: each variant = a different dubbing for this episode.
  if (allohaVariantsAndroid && allohaVariantsAndroid.length > 1 && CollapsParser.exoPlayerLaunchPlaylist) {
    await CollapsParser.exoPlayerLaunchPlaylist(
      allohaVariantsAndroid.map((v) => v.url),
      0,
      playbackHeaders,
      allohaVariantsAndroid.map((v) => v.title || title || ''),
      title,
      [],
      Number.isFinite(kpId) ? kpId : null
    );
    return;
  }

  const hlsUrl = activeEpisode.playlist.hlsUrl;
  const dashUrl = activeEpisode.playlist.dashUrl;
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
