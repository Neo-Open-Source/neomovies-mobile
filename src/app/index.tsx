import { useState } from 'react';
import { Pressable, RefreshControl, ScrollView, View } from 'react-native';
import { router } from 'expo-router';
import { Search } from 'lucide-react-native';

import { MediaCarouselSection } from '@/components/home/media-carousel-section';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useHomeScreenData } from '@/hooks/use-home-screen-data';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { homeScreenStyles } from '@/styles/home-screen.styles';

export default function HomeScreen() {
  const { copy } = useI18n();
  const theme = useTheme();
  const { loading, error, popular, topFilms, topSeries, refresh } = useHomeScreenData();
  const [refreshing, setRefreshing] = useState(false);

  const onRefresh = async () => {
    setRefreshing(true);
    try {
      await refresh();
    } finally {
      setRefreshing(false);
    }
  };

  return (
    <ThemedView style={homeScreenStyles.container}>
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={homeScreenStyles.content}
        contentInsetAdjustmentBehavior="automatic"
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={theme.accent} />
        }
      >
        <Pressable onPress={() => router.push('/explore')}>
          <ThemedView type="backgroundElement" style={homeScreenStyles.searchRow}>
            <Search size={18} color={theme.textMuted} />
            <ThemedText type="small" themeColor="textMuted">
              {copy.search.placeholder}
            </ThemedText>
          </ThemedView>
        </Pressable>

        <MediaCarouselSection
          title={copy.home.popular}
          items={popular}
          categoryKind="popular"
          variant="backdrop"
          loading={loading}
        />
        <MediaCarouselSection
          title={copy.home.topFilms}
          items={topFilms}
          categoryKind="top-films"
          variant="poster"
          loading={loading}
        />
        <MediaCarouselSection
          title={copy.home.topSeries}
          items={topSeries}
          categoryKind="top-series"
          variant="poster"
          loading={loading}
        />

        {error ? (
          <ThemedView
            type="backgroundElement"
            style={[homeScreenStyles.errorCard, { borderColor: theme.danger }]}>
            <ThemedText type="small" themeColor="danger">
              {copy.home.loadError}: {error}
            </ThemedText>
          </ThemedView>
        ) : null}
      </ScrollView>
    </ThemedView>
  );
}
