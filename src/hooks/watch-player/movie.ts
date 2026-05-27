import { Platform } from 'react-native';

import { avPlayerConfigurePlaylist, avPlayerPresentNativeUI } from '@/native/collaps-parser';
import NeomoviesCore from 'neomovies-core';

import { normalizeMediaFileId, shouldPreferHlsForAndroidExo } from './helpers';
import { rewriteDashToLocalOrFallback, rewriteHlsToLocalOrFallback } from './manifest';
import { MovieCatalog, PlayerHeaders } from './types';

export async function launchMoviePlayer(
  catalog: MovieCatalog,
  playbackHeaders: PlayerHeaders,
  title: string | null,
  mediaId: string
) {
  if (Platform.OS === 'ios') {
    return launchIOSMoviePlayer(catalog, playbackHeaders, title, mediaId);
  }
  return launchAndroidMoviePlayer(catalog, playbackHeaders, title, mediaId);
}

async function launchIOSMoviePlayer(
  catalog: MovieCatalog,
  playbackHeaders: PlayerHeaders,
  title: string | null,
  mediaId: string
) {
  const kpId = Number(mediaId.replace(/^kp_/, ''));
  const allohaVariants = catalog.allohaVariants;
  const headers = { Referer: playbackHeaders.Referer, Origin: playbackHeaders.Origin };

  const playlistItems = allohaVariants && allohaVariants.length > 1
    ? allohaVariants.map((variant) => ({
        mediaId,
        title: variant.title || title || '',
        url: variant.url,
        headers,
        voiceovers: [],
        subtitles: catalog.playlist.subtitles,
      }))
    : (() => {
        const url = catalog.playlist.hlsUrl ?? catalog.playlist.dashUrl ?? catalog.playlist.primaryUrl;
        if (!url) return null;
        return [{
          mediaId: mediaId || url,
          title: title ?? '',
          url,
          headers,
          voiceovers: catalog.playlist.voiceovers,
          subtitles: catalog.playlist.subtitles,
        }];
      })();

  if (!playlistItems) return;
  await avPlayerConfigurePlaylist(playlistItems, 0, true, Number.isFinite(kpId) ? kpId : null);
  await avPlayerPresentNativeUI();
}

async function launchAndroidMoviePlayer(
  catalog: MovieCatalog,
  playbackHeaders: PlayerHeaders,
  title: string | null,
  mediaId: string
) {
  const kpId = Number(mediaId.replace(/^kp_/, ''));
  const allohaVariants = catalog.allohaVariants;

  if (allohaVariants && allohaVariants.length > 1 && NeomoviesCore.exoPlayerLaunchPlaylist) {
    await NeomoviesCore.exoPlayerLaunchPlaylist(
      allohaVariants.map((variant) => variant.url),
      0,
      playbackHeaders,
      allohaVariants.map((variant) => variant.title || title || ''),
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
  const mediaFileId = normalizeMediaFileId(mediaId, 'movie');

  let finalUrl: string;
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
  await NeomoviesCore.exoPlayerLaunch?.(finalUrl, playbackHeaders, title, Number.isFinite(kpId) ? kpId : null);
}
