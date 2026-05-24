import { Platform } from 'react-native';
import CollapsParser from 'neomovies-core';

export type CollapsSubtitle = {
  url: string;
  label: string;
  language: string;
};

export type CollapsPlaylist = {
  primaryUrl: string;
  hlsUrl: string | null;
  dashUrl: string | null;
  voiceovers: string[];
  subtitles: CollapsSubtitle[];
};

export type CollapsEpisode = {
  season: number;
  episode: number;
  title: string;
  playlist: CollapsPlaylist;
};

export type CollapsSeason = {
  season: number;
  title: string;
  episodes: CollapsEpisode[];
};

export type CollapsCatalogMovie = {
  kind: 'movie';
  source: string;
  playlist: CollapsPlaylist;
};

export type CollapsCatalogSeries = {
  kind: 'series';
  source: string;
  seasons: CollapsSeason[];
};

export type CollapsCatalog = CollapsCatalogMovie | CollapsCatalogSeries;

export type AVPlayerState = {
  isLoaded: boolean;
  isPlaying: boolean;
  rate: number;
  currentTimeSec: number;
  durationSec: number;
  currentIndex: number;
  totalItems: number;
  season: number | null;
  episode: number | null;
  mediaId: string | null;
};

export type AVPlayerTrack = {
  index: number;
  id: string;
  label: string;
  language: string;
};

export type AVPlayerQualityOption = {
  index: number;
  bitrate: number;
  height: number | null;
  label: string;
  isAuto: boolean;
};

export type CollapsWatchProgressRecord = {
  schemaVersion: number;
  source: 'collaps';
  mediaId: string;
  kpId: number;
  season: number | null;
  episode: number | null;
  kind: 'episode' | 'movie_or_generic';
  positionMs: number;
  durationMs: number;
  progressPercent: number;
  watched: boolean;
  updatedAtMs: number;
};

export type CollapsWatchProgressSnapshot = CollapsWatchProgressRecord & {
  lastSeason: number | null;
  lastEpisode: number | null;
  lastPositionMs: number;
  lastDurationMs: number;
  lastUpdatedAtMs: number;
};

type NeomoviesCoreModule = {
  parseCollapsCatalog(embedHtml: string): CollapsCatalog;
  rewriteCollapsHlsMaster(master: string, voices: string[], subtitles: CollapsSubtitle[], mediaId: string): string;
  rewriteCollapsDashManifest(manifest: string, voices: string[], subtitles: CollapsSubtitle[], mediaId: string): string;
  rewriteCollapsHlsFromUrl(
    hlsUrl: string,
    voices: string[],
    subtitles: CollapsSubtitle[],
    mediaId: string,
    referer?: string | null,
    origin?: string | null
  ): Promise<string>;
  rewriteCollapsDashFromUrl(
    dashUrl: string,
    voices: string[],
    subtitles: CollapsSubtitle[],
    mediaId: string,
    referer?: string | null,
    origin?: string | null
  ): Promise<string>;
  collapsDashContainsAv1(
    dashUrl: string,
    referer?: string | null,
    origin?: string | null
  ): Promise<boolean>;
  collapsDeviceSupportsAv1?(): boolean;
  avPlayerLoad(
    url: string,
    headers: Record<string, string>,
    autoplay: boolean,
    startPositionSec?: number | null
  ): Promise<AVPlayerState>;
  avPlayerConfigurePlaylist(
    items: Array<{
      mediaId?: string;
      title?: string;
      url: string;
      headers?: Record<string, string>;
      season?: number;
      episode?: number;
      voiceovers?: string[];
      subtitles?: CollapsSubtitle[];
    }>,
    startIndex: number,
    autoplay: boolean
  ): Promise<AVPlayerState>;
  avPlayerPresentNativeUI(): Promise<void>;
  avPlayerDismissNativeUI(): Promise<void>;
  avPlayerSelectEpisode(index: number, autoplay: boolean): Promise<AVPlayerState>;
  avPlayerNextEpisode(autoplay: boolean): Promise<AVPlayerState>;
  avPlayerPreviousEpisode(autoplay: boolean): Promise<AVPlayerState>;
  avPlayerPlay(): AVPlayerState;
  avPlayerPause(): AVPlayerState;
  avPlayerStop(): void;
  avPlayerSeek(positionSec: number): AVPlayerState;
  avPlayerSetRate(rate: number): AVPlayerState;
  avPlayerSetPreferredPeakBitRate(bitrate: number): void;
  avPlayerRefreshQualityOptions(): Promise<AVPlayerQualityOption[]>;
  avPlayerListQualityOptions(): AVPlayerQualityOption[];
  avPlayerSelectQuality(index?: number | null): void;
  avPlayerSnapshot(): AVPlayerState;
  avPlayerListAudioTracks(): AVPlayerTrack[];
  avPlayerSelectAudioTrack(index?: number | null): void;
  avPlayerListSubtitleTracks(): AVPlayerTrack[];
  avPlayerSelectSubtitleTrack(index?: number | null): void;
  getCollapsWatchProgress?(kpId: number, season?: number | null, episode?: number | null): {
    schemaVersion: number;
    source: 'collaps';
    mediaId: string;
    kpId: number;
    season: number | null;
    episode: number | null;
    kind: 'episode' | 'movie_or_generic';
    positionMs: number;
    durationMs: number;
    progressPercent: number;
    watched: boolean;
    updatedAtMs: number;
    lastSeason: number | null;
    lastEpisode: number | null;
    lastPositionMs: number;
    lastDurationMs: number;
    lastUpdatedAtMs: number;
  };
  listCollapsWatchProgressRecords?(kpId?: number | null): CollapsWatchProgressRecord[];
};

let nativeModule: NeomoviesCoreModule | null = null;
const LOG_PREFIX = '[CollapsNative]';

function debugLog(message: string, payload?: unknown) {
  if (__DEV__) {
    if (payload === undefined) {
      console.log(`${LOG_PREFIX} ${message}`);
    } else {
      console.log(`${LOG_PREFIX} ${message}`, payload);
    }
  }
}

function getNativeModule(): NeomoviesCoreModule {
  debugLog('getNativeModule:start', { platform: Platform.OS });
  if (!nativeModule) {
    debugLog('NeomoviesCore linked successfully');
    nativeModule = CollapsParser as NeomoviesCoreModule;
  }
  return nativeModule;
}

type Subscription = { remove: () => void };

function addNativeListener(event: string, listener: (state: AVPlayerState) => void): Subscription {
  const module = getNativeModule() as unknown as {
    addListener?: (eventName: string, listener: (payload: AVPlayerState) => void) => Subscription;
  };
  if (!module.addListener) {
    throw new Error('NeomoviesCore event emitter is not available');
  }
  return module.addListener(event, listener);
}

export async function parseCollapsCatalog(embedHtml: string): Promise<CollapsCatalog> {
  debugLog('parseCollapsCatalog:called', { payloadLength: embedHtml.length });
  if (!embedHtml.trim()) {
    throw new Error('Empty Collaps payload');
  }
  const module = getNativeModule();
  const result = module.parseCollapsCatalog(embedHtml);
  debugLog('parseCollapsCatalog:done', { kind: result.kind });
  return result;
}

export async function rewriteCollapsHlsMaster(
  master: string,
  voices: string[],
  subtitles: CollapsSubtitle[] = [],
  mediaId: string
): Promise<string> {
  debugLog('rewriteCollapsHlsMaster:called', {
    payloadLength: master.length,
    voices: voices.length,
    subtitles: subtitles.length,
    mediaId,
  });
  const module = getNativeModule();
  const rewritten = module.rewriteCollapsHlsMaster(master, voices, subtitles, mediaId);
  debugLog('rewriteCollapsHlsMaster:done', { payloadLength: rewritten.length });
  return rewritten;
}

export async function rewriteCollapsDashManifest(
  manifest: string,
  voices: string[],
  subtitles: CollapsSubtitle[] = [],
  mediaId: string
): Promise<string> {
  debugLog('rewriteCollapsDashManifest:called', {
    payloadLength: manifest.length,
    voices: voices.length,
    subtitles: subtitles.length,
    mediaId,
  });
  const module = getNativeModule();
  const rewritten = module.rewriteCollapsDashManifest(manifest, voices, subtitles, mediaId);
  debugLog('rewriteCollapsDashManifest:done', { payloadLength: rewritten.length });
  return rewritten;
}

export async function rewriteCollapsHlsFromUrl(
  hlsUrl: string,
  voices: string[],
  subtitles: CollapsSubtitle[] = [],
  mediaId: string,
  headers?: { referer?: string | null; origin?: string | null }
): Promise<string> {
  debugLog('rewriteCollapsHlsFromUrl:called', {
    hlsUrl,
    voices: voices.length,
    subtitles: subtitles.length,
    mediaId,
    referer: headers?.referer ?? null,
    origin: headers?.origin ?? null,
  });
  const module = getNativeModule();
  const rewritten = await module.rewriteCollapsHlsFromUrl(
    hlsUrl,
    voices,
    subtitles,
    mediaId,
    headers?.referer ?? null,
    headers?.origin ?? null
  );
  debugLog('rewriteCollapsHlsFromUrl:done', { payloadLength: rewritten.length });
  return rewritten;
}

export async function rewriteCollapsDashFromUrl(
  dashUrl: string,
  voices: string[],
  subtitles: CollapsSubtitle[] = [],
  mediaId: string,
  headers?: { referer?: string | null; origin?: string | null }
): Promise<string> {
  debugLog('rewriteCollapsDashFromUrl:called', {
    dashUrl,
    voices: voices.length,
    subtitles: subtitles.length,
    mediaId,
    referer: headers?.referer ?? null,
    origin: headers?.origin ?? null,
  });
  const module = getNativeModule();
  const rewritten = await module.rewriteCollapsDashFromUrl(
    dashUrl,
    voices,
    subtitles,
    mediaId,
    headers?.referer ?? null,
    headers?.origin ?? null
  );
  debugLog('rewriteCollapsDashFromUrl:done', { payloadLength: rewritten.length });
  return rewritten;
}

export async function collapsDashContainsAv1(
  dashUrl: string,
  headers?: { referer?: string | null; origin?: string | null }
): Promise<boolean> {
  debugLog('collapsDashContainsAv1:called', {
    dashUrl,
    referer: headers?.referer ?? null,
    origin: headers?.origin ?? null,
  });
  const module = getNativeModule();
  const result = await module.collapsDashContainsAv1(
    dashUrl,
    headers?.referer ?? null,
    headers?.origin ?? null
  );
  debugLog('collapsDashContainsAv1:done', { result });
  return result;
}

export function collapsDeviceSupportsAv1(): boolean {
  const module = getNativeModule();
  return module.collapsDeviceSupportsAv1?.() ?? false;
}

export async function avPlayerLoad(
  url: string,
  options?: {
    headers?: Record<string, string>;
    autoplay?: boolean;
    startPositionSec?: number | null;
  }
): Promise<AVPlayerState> {
  const module = getNativeModule();
  return module.avPlayerLoad(
    url,
    options?.headers ?? {},
    options?.autoplay ?? true,
    options?.startPositionSec ?? null
  );
}

export async function avPlayerConfigurePlaylist(
  items: Array<{
    mediaId?: string;
    title?: string;
    url: string;
    headers?: Record<string, string>;
    season?: number;
    episode?: number;
    voiceovers?: string[];
    subtitles?: CollapsSubtitle[];
  }>,
  startIndex = 0,
  autoplay = true
): Promise<AVPlayerState> {
  return getNativeModule().avPlayerConfigurePlaylist(items, startIndex, autoplay);
}

export async function avPlayerPresentNativeUI(): Promise<void> {
  await getNativeModule().avPlayerPresentNativeUI();
}

export async function avPlayerDismissNativeUI(): Promise<void> {
  await getNativeModule().avPlayerDismissNativeUI();
}

export async function avPlayerSelectEpisode(index: number, autoplay = true): Promise<AVPlayerState> {
  return getNativeModule().avPlayerSelectEpisode(index, autoplay);
}

export async function avPlayerNextEpisode(autoplay = true): Promise<AVPlayerState> {
  return getNativeModule().avPlayerNextEpisode(autoplay);
}

export async function avPlayerPreviousEpisode(autoplay = true): Promise<AVPlayerState> {
  return getNativeModule().avPlayerPreviousEpisode(autoplay);
}

export function avPlayerPlay(): AVPlayerState {
  return getNativeModule().avPlayerPlay();
}

export function avPlayerPause(): AVPlayerState {
  return getNativeModule().avPlayerPause();
}

export function avPlayerStop(): void {
  getNativeModule().avPlayerStop();
}

export function avPlayerSeek(positionSec: number): AVPlayerState {
  return getNativeModule().avPlayerSeek(positionSec);
}

export function avPlayerSetRate(rate: number): AVPlayerState {
  return getNativeModule().avPlayerSetRate(rate);
}

export function avPlayerSetPreferredPeakBitRate(bitrate: number): void {
  getNativeModule().avPlayerSetPreferredPeakBitRate(bitrate);
}

export async function avPlayerRefreshQualityOptions(): Promise<AVPlayerQualityOption[]> {
  return getNativeModule().avPlayerRefreshQualityOptions();
}

export function avPlayerListQualityOptions(): AVPlayerQualityOption[] {
  return getNativeModule().avPlayerListQualityOptions();
}

export function avPlayerSelectQuality(index?: number | null): void {
  getNativeModule().avPlayerSelectQuality(index ?? null);
}

export function avPlayerSnapshot(): AVPlayerState {
  return getNativeModule().avPlayerSnapshot();
}

export function avPlayerListAudioTracks(): AVPlayerTrack[] {
  return getNativeModule().avPlayerListAudioTracks();
}

export function avPlayerSelectAudioTrack(index?: number | null): void {
  getNativeModule().avPlayerSelectAudioTrack(index ?? null);
}

export function avPlayerListSubtitleTracks(): AVPlayerTrack[] {
  return getNativeModule().avPlayerListSubtitleTracks();
}

export function avPlayerSelectSubtitleTrack(index?: number | null): void {
  getNativeModule().avPlayerSelectSubtitleTrack(index ?? null);
}

export function addAVPlayerStateListener(listener: (state: AVPlayerState) => void) {
  return addNativeListener('onAVPlayerStateChanged', listener);
}

export function addAVPlayerProgressListener(listener: (state: AVPlayerState) => void) {
  return addNativeListener('onAVPlayerProgress', listener);
}

export function addAVPlayerEpisodeChangedListener(listener: (state: AVPlayerState) => void) {
  return addNativeListener('onAVPlayerEpisodeChanged', listener);
}

export function getCollapsWatchProgress(kpId: number, season?: number | null, episode?: number | null): CollapsWatchProgressSnapshot {
  return getNativeModule().getCollapsWatchProgress?.(kpId, season ?? null, episode ?? null) ?? {
    schemaVersion: 1,
    source: 'collaps',
    mediaId: `kp_${kpId}`,
    kpId,
    season: season ?? null,
    episode: episode ?? null,
    kind: season != null && episode != null ? 'episode' : 'movie_or_generic',
    positionMs: 0,
    durationMs: 0,
    progressPercent: 0,
    watched: false,
    updatedAtMs: 0,
    lastSeason: null,
    lastEpisode: null,
    lastPositionMs: 0,
    lastDurationMs: 0,
    lastUpdatedAtMs: 0,
  };
}

export function listCollapsWatchProgressRecords(kpId?: number | null): CollapsWatchProgressRecord[] {
  return getNativeModule().listCollapsWatchProgressRecords?.(kpId ?? null) ?? [];
}
