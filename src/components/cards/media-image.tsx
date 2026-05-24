import { Image } from 'expo-image';
import { useEffect, useMemo, useState } from 'react';
import { StyleProp, View, ViewStyle } from 'react-native';

import { ThemedView } from '@/components/themed-view';
import { mediaImageStyles } from '@/components/cards/media-image.styles';

type MediaImageProps = {
  primaryUri: string | null;
  fallbackUris?: Array<string | null | undefined>;
  style?: StyleProp<ViewStyle>;
  imageKey?: string;
};

export function MediaImage({ primaryUri, fallbackUris = [], style, imageKey }: MediaImageProps) {
  const sourceList = useMemo(() => {
    const list = [primaryUri, ...fallbackUris].filter((item): item is string => Boolean(item));
    return Array.from(new Set(list));
  }, [fallbackUris, primaryUri]);
  const sourceKey = useMemo(() => sourceList.join('|'), [sourceList]);
  const [sourceIndex, setSourceIndex] = useState(0);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    setSourceIndex(0);
    setLoaded(false);
  }, [sourceKey]);

  const onImageError = () => {
    if (sourceIndex + 1 < sourceList.length) {
      setSourceIndex((value) => value + 1);
      setLoaded(false);
      return;
    }
    setLoaded(true);
  };

  const resolvedUri = sourceList[sourceIndex];
  const recyclingKey = imageKey ? `${imageKey}:${resolvedUri ?? 'empty'}` : resolvedUri ?? sourceKey;

  return (
    <View style={[mediaImageStyles.container, style]}>
      {resolvedUri ? (
        <Image
          key={recyclingKey}
          source={{ uri: resolvedUri }}
          recyclingKey={recyclingKey}
          style={mediaImageStyles.image}
          contentFit="cover"
          transition={0}
          cachePolicy="memory-disk"
          priority="high"
          onLoad={() => setLoaded(true)}
          onError={onImageError}
        />
      ) : null}

      {!loaded ? (
        <View style={mediaImageStyles.placeholder}>
          <ThemedView type="backgroundSelected" style={mediaImageStyles.image} />
        </View>
      ) : null}
    </View>
  );
}
