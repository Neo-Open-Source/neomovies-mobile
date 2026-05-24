import { useEffect, useState } from 'react';

import { getMediaDetails } from '@/lib/neomovies-api';
import { MediaDetails } from '@/types/api';

export function useMediaDetails(mediaId?: string) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [details, setDetails] = useState<MediaDetails | null>(null);

  useEffect(() => {
    if (!mediaId) {
      setError('Missing media id');
      setDetails(null);
      setLoading(false);
      return;
    }

    let active = true;
    setLoading(true);
    setError(null);

    void getMediaDetails(mediaId)
      .then((response) => {
        if (!active) return;
        setDetails(response);
      })
      .catch((reason) => {
        if (!active) return;
        setError(reason instanceof Error ? reason.message : 'Request failed');
      })
      .finally(() => {
        if (!active) return;
        setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [mediaId]);

  return { loading, error, details };
}
