import { useLocalSearchParams } from 'expo-router';
import { useEffect, useMemo, useState } from 'react';
import { Platform, Pressable, ScrollView, View } from 'react-native';
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
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
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
  parseCollapsCatalog,
} from '@/native/collaps-parser';
import CollapsParser from 'neomovies-core';
import { getCollapsEmbedHtml } from '@/lib/neomovies-api';
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

export default function WatchSelectorScreen() {
  const params = useLocalSearchParams<{
    id?: string;
    title?: string;
    embed_html?: string;
    season?: string;
    episode?: string;
  }>();
  const { copy } = useI18n();
  const theme = useTheme();
  const styles = createWatchSelectorStyles(theme);

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [catalog, setCatalog] = useState<CollapsCatalog | null>(null);

  const initialSeason = Number(params.season ?? '1') || 1;
  const initialEpisode = Number(params.episode ?? '1') || 1;

  const [selectedSeason, setSelectedSeason] = useState(initialSeason);
  const [selectedEpisode, setSelectedEpisode] = useState(initialEpisode);
  const [nativeProgressSec, setNativeProgressSec] = useState(0);
  const [playbackHeaders, setPlaybackHeaders] = useState<PlayerHeaders>({
    Referer: 'https://kinokrad.my/',
    Origin: 'https://kinokrad.my',
  });

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    void (async () => {
      try {
        let embedHtml = typeof params.embed_html === 'string' ? decodeURIComponent(params.embed_html) : '';
        let nextHeaders: PlayerHeaders = {
          Referer: API_ORIGIN.endsWith('/') ? API_ORIGIN : `${API_ORIGIN}/`,
          Origin: API_ORIGIN,
        };
        if (!embedHtml.trim()) {
          const mediaId = params.id ?? '';
          if (!mediaId) {
            throw new Error('Missing media id for Collaps player');
          }
          const payload = await getCollapsEmbedHtml(mediaId, initialSeason, initialEpisode);
          embedHtml = payload.embedHtml;
          nextHeaders = {
            Referer: payload.embedReferer,
            Origin: payload.embedOrigin,
          };
        }
        const next = await parseCollapsCatalog(embedHtml);
        console.log('[CollapsNative] parsed catalog', {
          kind: next.kind,
          movieVoices: next.kind === 'movie' ? next.playlist.voiceovers.length : undefined,
          movieVoicesPreview: next.kind === 'movie' ? next.playlist.voiceovers.slice(0, 6) : undefined,
          seasons: next.kind === 'series' ? next.seasons.length : undefined,
        });
        if (cancelled) return;
        setCatalog(next);
        setPlaybackHeaders(nextHeaders);
      } catch (reason) {
        if (cancelled) return;
        setCatalog(null);
        setError(reason instanceof Error ? reason.message : 'Request failed');
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [params.embed_html, params.id, initialSeason, initialEpisode]);

  useEffect(() => {
    if (Platform.OS !== 'ios') return;
    
    const progressSub = addAVPlayerProgressListener((state) => {
      setNativeProgressSec(state.currentTimeSec);
    });
    const episodeSub = addAVPlayerEpisodeChangedListener((state) => {
      if (typeof state.season === 'number') setSelectedSeason(state.season);
      if (typeof state.episode === 'number') setSelectedEpisode(state.episode);
    });
    return () => {
      progressSub.remove();
      episodeSub.remove();
    };
  }, []);

  const currentSeries = catalog?.kind === 'series' ? catalog : null;

  const activeSeason = useMemo(() => {
    if (!currentSeries) return null;
    return findSeasonByNumber(currentSeries.seasons, selectedSeason);
  }, [currentSeries, selectedSeason]);

  const activeEpisode = useMemo(() => {
    if (!activeSeason) return null;
    return findEpisodeByNumber(activeSeason.episodes, selectedEpisode);
  }, [activeSeason, selectedEpisode]);

  useEffect(() => {
    if (!activeSeason) return;
    const fallbackEpisode = activeSeason.episodes[0]?.episode;
    if (!activeSeason.episodes.some((item) => item.episode === selectedEpisode) && fallbackEpisode) {
      setSelectedEpisode(fallbackEpisode);
    }
  }, [activeSeason, selectedEpisode]);

  const openExoPlayer = async () => {
    if (!catalog) return;
    if (catalog.kind === 'movie') {
      const hlsUrl = catalog.playlist.hlsUrl;
      const dashUrl = catalog.playlist.dashUrl;
      const primaryUrl = catalog.playlist.primaryUrl;
      const preferHls = await shouldPreferHlsForAndroidExo(hlsUrl, dashUrl, playbackHeaders);

      let finalUrl: string;
      const mediaFileId = normalizeMediaFileId(params.id, 'movie');

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

      console.log('[CollapsNative] openExoPlayer:selected', {
        mediaId: mediaFileId,
        preferHls,
        voicesCount: catalog.playlist.voiceovers.length,
        voicesPreview: catalog.playlist.voiceovers.slice(0, 6),
        hlsUrl,
        dashUrl,
        finalUrl,
      });
      // Pass file:// URI with headers
      await CollapsParser.exoPlayerLaunch?.(finalUrl, playbackHeaders, params.title ?? null);
    }
  };

  const openExoPlayerSeriesEpisode = async () => {
    if (!currentSeries || !activeEpisode) return;
    const hlsUrl = activeEpisode.playlist.hlsUrl;
    const dashUrl = activeEpisode.playlist.dashUrl;
    const primaryUrl = activeEpisode.playlist.primaryUrl;
    const seriesBaseId = normalizeMediaFileId(params.id, 'series');
    const mediaId = `${seriesBaseId}_${activeEpisode.season}_${activeEpisode.episode}`;
    const preferHls = await shouldPreferHlsForAndroidExo(hlsUrl, dashUrl, playbackHeaders);

    let finalUrl: string;

    if (preferHls && hlsUrl) {
      finalUrl = await rewriteHlsToLocalOrFallback(
        hlsUrl,
        activeEpisode.playlist.voiceovers,
        activeEpisode.playlist.subtitles,
        mediaId,
        playbackHeaders
      );
    } else if (dashUrl) {
      const dashLocalOrNull = await rewriteDashToLocalOrFallback(
        dashUrl,
        activeEpisode.playlist.voiceovers,
        activeEpisode.playlist.subtitles,
        mediaId,
        playbackHeaders
      );
      if (dashLocalOrNull) {
        finalUrl = dashLocalOrNull;
      } else if (hlsUrl) {
        finalUrl = await rewriteHlsToLocalOrFallback(
          hlsUrl,
          activeEpisode.playlist.voiceovers,
          activeEpisode.playlist.subtitles,
          mediaId,
          playbackHeaders
        );
      } else {
        finalUrl = dashUrl;
      }
    } else {
      finalUrl = primaryUrl;
    }

    if (!finalUrl) return;
    console.log('[CollapsNative] openExoPlayerSeriesEpisode:selected', {
      mediaId,
      preferHls,
      voicesCount: activeEpisode.playlist.voiceovers.length,
      voicesPreview: activeEpisode.playlist.voiceovers.slice(0, 6),
      hlsUrl,
      dashUrl,
      finalUrl,
    });
    const seasonPlaylist = currentSeries.seasons
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
            name: `${params.title ?? 'Series'}_S${String(season.season).padStart(2, '0')}E${String(episode.episode).padStart(2, '0')}`,
          }))
          .filter((item) => Boolean(item.url))
      );

    const startIndex = Math.max(
      0,
      seasonPlaylist.findIndex((item) => item.season === activeEpisode.season && item.episode === activeEpisode.episode)
    );

    console.log('[CollapsNative] exoPlayerLaunchPlaylist payload', {
      count: seasonPlaylist.length,
      startIndex,
      firstNames: seasonPlaylist.slice(0, 5).map((item) => item.name),
    });

    if (CollapsParser.exoPlayerLaunchPlaylist && seasonPlaylist.length > 0) {
      await CollapsParser.exoPlayerLaunchPlaylist(
        seasonPlaylist.map((item) => item.url),
        startIndex,
        playbackHeaders,
        seasonPlaylist.map((item) => item.name),
        params.title ?? null,
        activeEpisode.playlist.voiceovers
      );
      return;
    }

    await CollapsParser.exoPlayerLaunch?.(
      finalUrl,
      playbackHeaders,
      `${params.title ?? 'Series'} S${String(activeEpisode.season).padStart(2, '0')}E${String(activeEpisode.episode).padStart(2, '0')}`
    );
  };

  const openNativePlayer = async () => {
    if (Platform.OS !== 'ios') {
      console.warn('AVPlayer is only available on iOS');
      return;
    }
    if (!catalog) return;
    if (catalog.kind === 'movie') {
      const url = catalog.playlist.hlsUrl ?? catalog.playlist.dashUrl ?? catalog.playlist.primaryUrl;
      if (!url) return;
      await avPlayerConfigurePlaylist(
        [
          {
            mediaId: params.id ?? url,
            title: params.title ?? '',
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

    const playlistItems = catalog.seasons
      .flatMap((season) =>
        season.episodes.map((episode) => ({
          mediaId: `${params.id ?? 'series'}_s${season.season}_e${episode.episode}`,
          title: `${params.title ?? 'Series'} S${season.season}E${episode.episode}`,
          url: episode.playlist.hlsUrl ?? episode.playlist.dashUrl ?? episode.playlist.primaryUrl,
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
      playlistItems.findIndex((item) => item.season === selectedSeason && item.episode === selectedEpisode)
    );

    await avPlayerConfigurePlaylist(playlistItems, startIndex, true);
    await avPlayerPresentNativeUI();
  };

  const switchEpisodeNative = async (season: number, episode: number) => {
    if (!currentSeries) return;
    const flattened = currentSeries.seasons.flatMap((s) => s.episodes.map((e) => ({ season: s.season, episode: e.episode })));
    const index = flattened.findIndex((item) => item.season === season && item.episode === episode);
    if (index >= 0) {
      await avPlayerSelectEpisode(index, true);
      await avPlayerPresentNativeUI();
    }
  };

  return (
    <ThemedView style={styles.container}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.content}>
        {loading ? (
          <ThemedText themeColor="textSecondary">{copy.home.loading}</ThemedText>
        ) : null}

        {!loading && error ? (
          <View style={styles.card}>
            <ThemedText themeColor="danger" style={styles.title}>
              {copy.search.loadError}
            </ThemedText>
            <ThemedText style={styles.subtitle}>{error}</ThemedText>
            <ThemedText style={styles.subtitle}>{copy.watchSelector.missingPayload}</ThemedText>
          </View>
        ) : null}

        {!loading && !error && catalog?.kind === 'movie' ? (
          <View style={styles.card}>
            <ThemedText style={styles.title}>{copy.media.movie}</ThemedText>
            <ThemedText style={styles.subtitle}>{params.title ?? ''}</ThemedText>

            <View style={styles.urlBlock}>
              <ThemedText type="small" style={styles.sectionTitle}>{copy.watchSelector.primary}</ThemedText>
              <ThemedText type="small">{catalog.playlist.primaryUrl}</ThemedText>
            </View>
            {Platform.OS === 'ios' && (
              <Pressable style={styles.episodeButtonActive} onPress={() => void openNativePlayer()}>
                <ThemedText type="small">Play Native (AVPlayer)</ThemedText>
              </Pressable>
            )}
            {Platform.OS === 'android' && (
              <Pressable style={styles.episodeButtonActive} onPress={() => void openExoPlayer()}>
                <ThemedText type="small">Play Native (ExoPlayer)</ThemedText>
              </Pressable>
            )}

            {catalog.playlist.hlsUrl ? (
              <View style={styles.urlBlock}>
                <ThemedText type="small" style={styles.sectionTitle}>HLS (m3u8)</ThemedText>
                <ThemedText type="small">{catalog.playlist.hlsUrl}</ThemedText>
              </View>
            ) : null}

            {catalog.playlist.dashUrl ? (
              <View style={styles.urlBlock}>
                <ThemedText type="small" style={styles.sectionTitle}>DASH (mpd)</ThemedText>
                <ThemedText type="small">{catalog.playlist.dashUrl}</ThemedText>
              </View>
            ) : null}
          </View>
        ) : null}

        {!loading && !error && currentSeries ? (
          <View style={styles.card}>
            <ThemedText style={styles.title}>{copy.media.tv}</ThemedText>
            <ThemedText style={styles.subtitle}>{params.title ?? ''}</ThemedText>

            <ThemedText style={styles.sectionTitle}>{copy.watchSelector.seasons}</ThemedText>
            <View style={styles.pillRow}>
              {currentSeries.seasons.map((season) => {
                const active = season.season === (activeSeason?.season ?? selectedSeason);
                return (
                  <Pressable
                    key={`season-${season.season}`}
                    style={[styles.seasonButton, active ? styles.seasonButtonActive : null]}
                    onPress={() => setSelectedSeason(season.season)}>
                    <ThemedText type="small">S{season.season}</ThemedText>
                  </Pressable>
                );
              })}
            </View>

            <ThemedText style={styles.sectionTitle}>{copy.watchSelector.episodes}</ThemedText>
            <View style={styles.pillRow}>
              {activeSeason?.episodes.map((episode) => {
                const active = episode.episode === (activeEpisode?.episode ?? selectedEpisode);
                return (
                  <Pressable
                    key={`episode-${episode.season}-${episode.episode}`}
                    style={[styles.episodeButton, active ? styles.episodeButtonActive : null]}
                    onPress={() => {
                      setSelectedEpisode(episode.episode);
                      if (Platform.OS === 'ios') {
                        void switchEpisodeNative(episode.season, episode.episode);
                      }
                    }}>
                    <ThemedText type="small">E{episode.episode}</ThemedText>
                  </Pressable>
                );
              })}
            </View>

            {activeEpisode ? (
              <>
                {Platform.OS === 'ios' && (
                  <Pressable style={styles.episodeButtonActive} onPress={() => void openNativePlayer()}>
                    <ThemedText type="small">Play Native (AVPlayer)</ThemedText>
                  </Pressable>
                )}
                {Platform.OS === 'android' && (
                  <Pressable style={styles.episodeButtonActive} onPress={() => void openExoPlayerSeriesEpisode()}>
                    <ThemedText type="small">Play Native (ExoPlayer)</ThemedText>
                  </Pressable>
                )}
                <View style={styles.urlBlock}>
                  <ThemedText type="small" style={styles.sectionTitle}>{copy.watchSelector.primary}</ThemedText>
                  <ThemedText type="small">{activeEpisode.playlist.primaryUrl}</ThemedText>
                </View>
                <View style={styles.urlBlock}>
                  <ThemedText type="small" style={styles.sectionTitle}>Native progress</ThemedText>
                  <ThemedText type="small">{Math.floor(nativeProgressSec)}s</ThemedText>
                </View>

                {activeEpisode.playlist.hlsUrl ? (
                  <View style={styles.urlBlock}>
                    <ThemedText type="small" style={styles.sectionTitle}>HLS (m3u8)</ThemedText>
                    <ThemedText type="small">{activeEpisode.playlist.hlsUrl}</ThemedText>
                  </View>
                ) : null}
              </>
            ) : null}
          </View>
        ) : null}
      </ScrollView>
    </ThemedView>
  );
}
