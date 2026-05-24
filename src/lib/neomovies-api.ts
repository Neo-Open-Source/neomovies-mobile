import { API_BASE_URL, API_ORIGIN } from '@/lib/config';
import { httpGet } from '@/lib/http';
import { getStoredTokens, refreshAccessToken } from '@/lib/neoid-auth';
import {
  ApiEnvelope,
  FavoriteItem,
  MediaDetails,
  PopularMoviesResponse,
  SearchResponse,
  TopRatedResponse,
} from '@/types/api';

function unwrapEnvelope<T>(response: ApiEnvelope<T> | T): T {
  if (
    response &&
    typeof response === 'object' &&
    'success' in response &&
    'data' in response
  ) {
    return (response as ApiEnvelope<T>).data;
  }
  return response as T;
}

async function authFetch(input: string, init?: RequestInit) {
  const tokens = await getStoredTokens();
  if (!tokens?.accessToken) {
    throw new Error('Not authenticated');
  }

  const run = async (accessToken: string) =>
    fetch(input, {
      ...init,
      headers: {
        Accept: 'application/json',
        ...(init?.headers ?? {}),
        Authorization: `Bearer ${accessToken}`,
      },
    });

  let response = await run(tokens.accessToken);
  if (response.status !== 401) return response;

  const nextToken = await refreshAccessToken();
  if (!nextToken) return response;
  response = await run(nextToken);
  return response;
}

async function authGet<T>(url: string): Promise<T> {
  const response = await authFetch(url, { method: 'GET' });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${text || 'Request failed'}`);
  }
  const payload = (text ? JSON.parse(text) : {}) as ApiEnvelope<T> | T;
  return unwrapEnvelope(payload);
}

async function authMutate<T>(url: string, method: 'POST' | 'DELETE'): Promise<T> {
  const response = await authFetch(url, { method });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${text || 'Request failed'}`);
  }
  const payload = (text ? JSON.parse(text) : {}) as ApiEnvelope<T> | T;
  return unwrapEnvelope(payload);
}

export async function getPopularMovies(page = 1) {
  const url = `${API_BASE_URL}/movies/popular?page=${page}`;
  const response = await httpGet<ApiEnvelope<PopularMoviesResponse> | PopularMoviesResponse>(url);
  return unwrapEnvelope(response);
}

export async function searchMovies(query: string, page = 1) {
  const encoded = encodeURIComponent(query);
  const url = `${API_BASE_URL}/search?query=${encoded}&page=${page}`;
  const response = await httpGet<ApiEnvelope<SearchResponse> | SearchResponse>(url);
  return unwrapEnvelope(response);
}

export async function getTopFilms(page = 1) {
  const url = `${API_BASE_URL}/movies/top-rated?page=${page}`;
  const response = await httpGet<ApiEnvelope<TopRatedResponse> | TopRatedResponse>(url);
  return unwrapEnvelope(response);
}

export async function getTopSeries(page = 1) {
  const url = `${API_BASE_URL}/tv/top-rated?page=${page}`;
  const response = await httpGet<ApiEnvelope<TopRatedResponse> | TopRatedResponse>(url);
  return unwrapEnvelope(response);
}

export async function getMediaDetails(mediaId: string) {
  const rawId = mediaId.replace(/^kp_/, '');
  const url = `${API_BASE_URL}/movie/${rawId}`;
  const response = await httpGet<ApiEnvelope<MediaDetails> | MediaDetails>(url);
  return unwrapEnvelope(response);
}

function extractIframeSource(html: string): string | null {
  const match = html.match(/<iframe[^>]+src=["']([^"']+)["']/i);
  if (!match?.[1]) return null;
  return match[1];
}

export type CollapsEmbedPayload = {
  embedHtml: string;
  embedOrigin: string;
  embedReferer: string;
};

export async function getCollapsEmbedHtml(mediaId: string, season?: number, episode?: number): Promise<CollapsEmbedPayload> {
  const rawId = mediaId.replace(/^kp_/, '');
  const iframeSource = `https://api.luxembd.ws/embed/kp/${rawId}`;

  const embedResponse = await fetch(iframeSource, {
    method: 'GET',
    headers: {
      Accept: 'text/html,application/xhtml+xml',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      Referer: 'https://kinokrad.my/',
      Origin: 'https://kinokrad.my',
    },
  });
  const embedHtml = await embedResponse.text();
  if (!embedResponse.ok) {
    throw new Error(`HTTP ${embedResponse.status}: ${embedHtml || 'Failed to load Collaps embed HTML'}`);
  }

  return {
    embedHtml,
    embedOrigin: 'https://kinokrad.my',
    embedReferer: 'https://kinokrad.my/',
  };
}

export async function getFavorites() {
  const url = `${API_BASE_URL}/favorites`;
  return authGet<FavoriteItem[]>(url);
}

export async function checkFavorite(kpId: string, mediaType: 'movie' | 'tv') {
  const rawId = kpId.replace(/^kp_/, '');
  const type = encodeURIComponent(mediaType);
  const url = `${API_BASE_URL}/favorites/${rawId}/check?type=${type}`;
  return authGet<{ isFavorite: boolean }>(url);
}

export async function addFavorite(kpId: string, mediaType: 'movie' | 'tv') {
  const rawId = kpId.replace(/^kp_/, '');
  const type = encodeURIComponent(mediaType);
  const url = `${API_BASE_URL}/favorites/${rawId}?type=${type}`;
  return authMutate<{ mediaId: string }>(url, 'POST');
}

export async function removeFavorite(kpId: string, mediaType: 'movie' | 'tv') {
  const rawId = kpId.replace(/^kp_/, '');
  const type = encodeURIComponent(mediaType);
  const url = `${API_BASE_URL}/favorites/${rawId}?type=${type}`;
  return authMutate<{ mediaId: string }>(url, 'DELETE');
}

export function resolvePosterUrl(input?: string | null) {
  if (!input) return null;
  if (input.startsWith('http://') || input.startsWith('https://')) return input;
  if (input.startsWith('/api/')) return `${API_ORIGIN}${input}`;
  return `${API_ORIGIN}/${input.replace(/^\/+/, '')}`;
}

export function resolveBackdropUrl(movieId?: string | null, size: 'small' | 'large' = 'small') {
  if (!movieId) return null;
  const rawId = movieId.replace(/^kp_/, '');
  return `${API_BASE_URL}/images/backdrops/${rawId}/${size}`;
}

export function resolveBackdropPageUrl(movieId?: string | null, size: 'small' | 'large' = 'small') {
  if (!movieId) return null;
  const rawId = movieId.replace(/^kp_/, '');
  return `${API_BASE_URL}/images/backdrops/page/${rawId}/${size}`;
}

export function resolveLogoUrl(movieId?: string | null, size: 'w500' | 'original' = 'w500') {
  if (!movieId) return null;
  const rawId = movieId.replace(/^kp_/, '');
  return `${API_BASE_URL}/images/logos/${rawId}/${size}`;
}
