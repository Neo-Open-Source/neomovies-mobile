import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import {
  FlatList,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  TextInput,
  useWindowDimensions,
  View,
} from 'react-native';
import { Clock3, Search, X } from 'lucide-react-native';

import { PosterCard } from '@/components/cards/poster-card';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useSearchScreen } from '@/hooks/use-search-screen';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { createSearchScreenStyles } from '@/styles/search-screen.styles';
import { SearchResultItem } from '@/types/api';

const SEARCH_CARD_MIN_WIDTH = 150;
const SEARCH_CARD_GAP = 16;
const SEARCH_SKELETON_COUNT = 10;

type GridItem = { kind: 'result'; value: SearchResultItem } | { kind: 'skeleton'; id: string };

export default function SearchScreen() {
  const { copy } = useI18n();
  const theme = useTheme();
  const { width } = useWindowDimensions();
  const columns = Math.max(
    1,
    Math.floor(
      (Math.max(width - 32, SEARCH_CARD_MIN_WIDTH) + SEARCH_CARD_GAP) /
        (SEARCH_CARD_MIN_WIDTH + SEARCH_CARD_GAP)
    )
  );
  const styles = createSearchScreenStyles(theme);
  const {
    query,
    setQuery,
    loading,
    loadingMore,
    error,
    results,
    recentQueries,
    hasNextPage,
    removeRecentQuery,
    runSearch,
    loadNextPage,
    refresh,
    trackCurrentQuery,
  } = useSearchScreen();
  const [refreshing, setRefreshing] = useState(false);

  const cardWidth = useMemo(() => {
    const contentWidth = Math.max(width - 32, SEARCH_CARD_MIN_WIDTH);
    const totalGaps = SEARCH_CARD_GAP * Math.max(columns - 1, 0);
    return Math.floor((contentWidth - totalGaps) / columns);
  }, [columns, width]);

  const dynamicStyles = useMemo(
    () =>
      StyleSheet.create({
        gridItem: {
          width: cardWidth,
          maxWidth: cardWidth,
          flexGrow: 0,
          flexShrink: 0,
          flexBasis: cardWidth,
          alignSelf: 'flex-start',
        },
      }),
    [cardWidth]
  );

  const skeletonItems = useMemo<GridItem[]>(
    () =>
      Array.from({ length: SEARCH_SKELETON_COUNT }, (_, index) => ({
        kind: 'skeleton',
        id: `s-${index}`,
      })),
    []
  );
  const gridData = useMemo<GridItem[]>(() => {
    if (loading && results.length === 0) {
      return skeletonItems;
    }
    return results.map((value) => ({ kind: 'result', value }));
  }, [loading, results, skeletonItems]);

  const renderGridItem = ({ item }: { item: GridItem }) => {
    if (item.kind === 'skeleton') {
      return (
        <View style={[styles.gridItem, dynamicStyles.gridItem]}>
          <ThemedView type="backgroundSelected" style={styles.gridSkeleton} />
        </View>
      );
    }
    return (
      <View style={[styles.gridItem, dynamicStyles.gridItem]}>
        <Pressable
          onPress={() => {
            void trackCurrentQuery();
            router.push({
              pathname: '/media/[id]',
              params: { id: item.value.id, title: item.value.title },
            });
          }}>
          <PosterCard item={item.value} fluid />
        </Pressable>
      </View>
    );
  };

  const onRefresh = async () => {
    setRefreshing(true);
    try {
      await refresh();
    } finally {
      setRefreshing(false);
    }
  };

  return (
    <ThemedView style={styles.container}>
      <FlatList
        key={`search-grid-${columns}`}
        data={gridData}
        keyExtractor={(item) => (item.kind === 'result' ? item.value.id : item.id)}
        renderItem={renderGridItem}
        numColumns={columns}
        style={styles.resultsGrid}
        columnWrapperStyle={columns > 1 ? styles.rowGap : undefined}
        contentContainerStyle={styles.listContent}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={theme.accent} />
        }
        onEndReachedThreshold={0.45}
        onEndReached={() => {
          if (results.length > 0 && hasNextPage) {
            void loadNextPage();
          }
        }}
        ListHeaderComponent={
          <View style={styles.content}>
            <View style={styles.searchRow}>
              <TextInput
                value={query}
                onChangeText={setQuery}
                style={styles.input}
                placeholder={copy.search.placeholder}
                placeholderTextColor={theme.textSecondary}
                autoCapitalize="none"
                returnKeyType="search"
                onSubmitEditing={() => runSearch()}
              />
              <Pressable style={styles.searchAction} onPress={() => runSearch()} disabled={loading}>
                <Search size={19} strokeWidth={2.3} color={theme.accent} />
              </Pressable>
            </View>

            {recentQueries.length > 0 ? (
              <View style={styles.recentBlock}>
                <ThemedText style={styles.recentTitle} themeColor="textSecondary">
                  {copy.search.recentTitle}
                </ThemedText>
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={styles.recentRow}>
                  {recentQueries.map((item) => (
                    <View key={item} style={styles.recentChip}>
                      <View style={styles.recentChipIconWrap}>
                        <Clock3 size={13} strokeWidth={2.2} color={theme.textSecondary} />
                      </View>
                      <Pressable style={styles.recentChipMain} onPress={() => runSearch(item)}>
                        <ThemedText type="small" numberOfLines={1} style={styles.recentChipText}>
                          {item}
                        </ThemedText>
                      </Pressable>
                      <Pressable style={styles.recentChipRemove} onPress={() => removeRecentQuery(item)}>
                        <X size={14} strokeWidth={2.4} color={theme.textSecondary} />
                      </Pressable>
                    </View>
                  ))}
                </ScrollView>
              </View>
            ) : null}

            {error ? (
              <ThemedText type="small" themeColor="danger">
                {copy.search.loadError}: {error}
              </ThemedText>
            ) : null}
          </View>
        }
        ListEmptyComponent={
          !loading ? <ThemedText style={styles.emptyState}>{copy.search.emptyState}</ThemedText> : null
        }
        ListFooterComponent={null}
      />
    </ThemedView>
  );
}
