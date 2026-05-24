import { Image } from 'expo-image';
import { Download, Play } from 'lucide-react-native';
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Pressable, ScrollView, View } from 'react-native';

import { MediaImage } from '@/components/cards/media-image';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useMediaDetails } from '@/hooks/use-media-details';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { getStoredTokens } from '@/lib/neoid-auth';
import {
  addFavorite,
  checkFavorite,
  removeFavorite,
  resolveBackdropUrl,
  resolveLogoUrl,
  resolvePosterUrl,
} from '@/lib/neomovies-api';
import { resetMediaFavoriteHeader, setMediaFavoriteHeader } from '@/lib/media-favorite-header';
import { createMediaDetailsStyles } from '@/styles/media-details.styles';

export default function MediaDetailsScreen() {
  const params = useLocalSearchParams<{ id?: string }>();
  const theme = useTheme();
  const { copy } = useI18n();
  const styles = createMediaDetailsStyles(theme);
  const mediaId = params.id ?? '';
  const { loading, error, details } = useMediaDetails(mediaId);
  const [readyLogoUri, setReadyLogoUri] = useState<string | null>(null);
  const [logoFailed, setLogoFailed] = useState(false);
  const [isFavorite, setIsFavorite] = useState(false);
  const [favoriteBusy, setFavoriteBusy] = useState(false);
  const [favoriteStatusReady, setFavoriteStatusReady] = useState(false);
  const favoriteCheckVersionRef = useRef(0);

  const backdropUri = useMemo(
    () => (details ? resolveBackdropUrl(details.id, 'large') : null),
    [details]
  );
  const posterUri = useMemo(
    () => (details ? resolvePosterUrl(details.posterUrl) : null),
    [details]
  );
  const logoUri = useMemo(
    () => (details ? resolveLogoUrl(details.id, 'w500') : null),
    [details]
  );

  useEffect(() => {
    let active = true;
    setReadyLogoUri(null);
    setLogoFailed(false);

    if (!logoUri) return () => {
      active = false;
    };

    void Image.prefetch(logoUri, 'memory-disk')
      .then((result) => {
        if (!active || !result) return;
        setReadyLogoUri(logoUri);
      })
      .catch(() => {
        if (!active) return;
        setLogoFailed(true);
      });

    return () => {
      active = false;
    };
  }, [logoUri]);

  useEffect(() => {
    let active = true;
    const checkVersion = favoriteCheckVersionRef.current + 1;
    favoriteCheckVersionRef.current = checkVersion;
    setFavoriteStatusReady(false);
    void (async () => {
      if (!details) return;
      try {
        const tokens = await getStoredTokens();
        if (!tokens?.accessToken) {
          if (!active || checkVersion !== favoriteCheckVersionRef.current) return;
          setIsFavorite(false);
          setFavoriteStatusReady(true);
          return;
        }
        const result = await checkFavorite(details.id, details.type);
        if (!active || checkVersion !== favoriteCheckVersionRef.current) return;
        setIsFavorite(result.isFavorite === true);
        setFavoriteStatusReady(true);
      } catch {
        if (!active || checkVersion !== favoriteCheckVersionRef.current) return;
        setIsFavorite(false);
        setFavoriteStatusReady(true);
      }
    })();
    return () => {
      active = false;
    };
  }, [details]);

  const onToggleFavorite = async () => {
    if (!details || favoriteBusy) return;
    // Invalidate in-flight checkFavorite result so it cannot override optimistic toggle.
    favoriteCheckVersionRef.current += 1;
    setFavoriteBusy(true);
    setFavoriteStatusReady(true);
    const next = !isFavorite;
    setIsFavorite(next);
    try {
      if (next) {
        await addFavorite(details.id, details.type);
      } else {
        await removeFavorite(details.id, details.type);
      }
    } catch {
      setIsFavorite(!next);
    } finally {
      setFavoriteBusy(false);
    }
  };

  useEffect(() => {
    setMediaFavoriteHeader({
      visible: Boolean(details) && favoriteStatusReady,
      isFavorite,
      busy: favoriteBusy,
      onPress: () => {
        void onToggleFavorite();
      },
    });
    return () => {
      resetMediaFavoriteHeader();
    };
  }, [favoriteBusy, isFavorite, favoriteStatusReady, details?.id, details?.type]);

  return (
    <ThemedView style={styles.container}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.content}>
        {loading ? (
          <>
            <ThemedView type="backgroundSelected" style={styles.skeletonHero} />
            <ThemedView type="backgroundSelected" style={styles.skeleton} />
            <ThemedView type="backgroundSelected" style={styles.skeleton} />
          </>
        ) : null}

        {!loading && details ? (
          <>
            <View style={styles.heroCard}>
              <MediaImage
                primaryUri={backdropUri}
                fallbackUris={[posterUri]}
                style={styles.heroImage}
              />
              {!logoFailed && logoUri && readyLogoUri === logoUri ? (
                <View style={styles.logoWrap}>
                  <Image
                    source={{ uri: logoUri }}
                    style={styles.logo}
                    contentFit="contain"
                    transition={0}
                    onError={() => setLogoFailed(true)}
                  />
                </View>
              ) : null}
            </View>

            <ThemedText style={styles.title}>{details.title}</ThemedText>
            <View style={styles.metaRow}>
              <ThemedText style={styles.metaItem}>
                {details.type === 'tv' ? copy.media.tv : copy.media.movie}
              </ThemedText>
              {details.rating > 0 ? (
                <ThemedText style={styles.metaItem}>★ {details.rating.toFixed(1)}</ThemedText>
              ) : null}
              {!!details.releaseDate ? (
                <ThemedText style={styles.metaItem}>{details.releaseDate.slice(0, 4)}</ThemedText>
              ) : null}
            </View>
            {details.genres && details.genres.length > 0 ? (
              <View style={styles.genresRow}>
                {details.genres.map((genre) => (
                  <View key={genre.id} style={styles.genreChip}>
                    <ThemedText style={styles.genreText}>{genre.name}</ThemedText>
                  </View>
                ))}
              </View>
            ) : null}
            <View style={styles.actionsRow}>
              <Pressable
                style={styles.watchButton}
                onPress={() =>
                  router.push({
                    pathname: '/watch/[id]',
                    params: {
                      id: details.id,
                      title: details.title,
                    },
                  })
                }>
                <View style={styles.watchButtonContent}>
                  <Play size={18} strokeWidth={2.4} color="#FFFFFF" />
                  <ThemedText style={styles.watchButtonText}>{copy.media.watch}</ThemedText>
                </View>
              </Pressable>
              <Pressable
                style={styles.iconButton}
                accessibilityLabel={copy.media.download}>
                <Download size={20} strokeWidth={2.3} color={theme.text} />
              </Pressable>
            </View>
            {!!details.description ? (
              <ThemedText style={styles.description}>{details.description}</ThemedText>
            ) : null}
          </>
        ) : null}

        {!loading && error ? (
          <ThemedText type="small" themeColor="danger">
            {copy.home.loadError}: {error}
          </ThemedText>
        ) : null}
      </ScrollView>
    </ThemedView>
  );
}
