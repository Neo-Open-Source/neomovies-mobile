import { parseCollapsCatalog } from '@/native/collaps-parser';

import { buildAllohaSeriesCatalogFromApi } from './alloha';

export async function resolveCatalog(source: string, mediaId: string, embedHtml: string) {
  return source === 'alloha'
    ? await buildAllohaSeriesCatalogFromApi(mediaId)
    : await parseCollapsCatalog(embedHtml);
}
