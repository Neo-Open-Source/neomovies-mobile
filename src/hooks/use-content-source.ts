import * as SecureStore from 'expo-secure-store';
import { useCallback, useEffect, useState } from 'react';

export type ContentSource = 'collaps' | 'alloha';

const SOURCE_KEY = 'content_source_v1';

export function useContentSource() {
  const [source, setSourceState] = useState<ContentSource>('collaps');
  const [ready, setReady] = useState(false);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const stored = await SecureStore.getItemAsync(SOURCE_KEY);
        if (!active) return;
        if (stored === 'alloha' || stored === 'collaps') {
          setSourceState(stored);
        }
      } finally {
        if (active) setReady(true);
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  const setSource = useCallback(async (next: ContentSource) => {
    setSourceState(next);
    await SecureStore.setItemAsync(SOURCE_KEY, next);
  }, []);

  return { source, setSource, ready };
}
