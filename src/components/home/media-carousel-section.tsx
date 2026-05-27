import { router } from 'expo-router';
import { ChevronRight } from 'lucide-react-native';
import { Pressable, View } from 'react-native';
import { FlashList } from '@shopify/flash-list';

import { BackdropCard } from '@/components/cards/backdrop-card';
import { PosterCard } from '@/components/cards/poster-card';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { mediaCarouselSectionStyles } from '@/components/home/media-carousel-section.styles';
import { useTheme } from '@/hooks/use-theme';
import { PopularMovie } from '@/types/api';

type MediaCarouselSectionProps = {
  title: string;
  items: PopularMovie[];
  categoryKind: 'popular' | 'top-films' | 'top-series';
  variant?: 'poster' | 'backdrop';
  loading?: boolean;
};

export function MediaCarouselSection({
  title,
  items,
  categoryKind,
  variant = 'poster',
  loading = false,
}: MediaCarouselSectionProps) {
  const theme = useTheme();
  const CardComponent = variant === 'backdrop' ? BackdropCard : PosterCard;

  const skeletonStyle =
    variant === 'backdrop'
      ? mediaCarouselSectionStyles.skeletonBackdrop
      : mediaCarouselSectionStyles.skeletonPoster;
  const skeletonCount = variant === 'backdrop' ? 3 : 5;
  const estimatedItemSize = variant === 'backdrop' ? 280 : 160;
  const listHeight = variant === 'backdrop' ? 157 : 210;
  const drawDistance = estimatedItemSize * 6;

  return (
    <View style={mediaCarouselSectionStyles.sectionWrap}>
      <View style={mediaCarouselSectionStyles.headerRow}>
        <ThemedText style={mediaCarouselSectionStyles.sectionTitle}>{title}</ThemedText>
        <Pressable
          style={mediaCarouselSectionStyles.headerAction}
          onPress={() =>
            router.push({
              pathname: '/category/[kind]',
              params: { kind: categoryKind, title },
            })
          }>
          <ChevronRight size={22} color={theme.textSecondary} strokeWidth={2.6} />
        </Pressable>
      </View>
      <FlashList
        horizontal
        showsHorizontalScrollIndicator={false}
        data={loading ? Array.from({ length: skeletonCount }, (_, index) => ({ id: `skeleton-${index}` })) : items}
        estimatedItemSize={estimatedItemSize}
        drawDistance={drawDistance}
        disableHorizontalListHeightMeasurement
        removeClippedSubviews={false}
        style={{ height: listHeight }}
        contentContainerStyle={mediaCarouselSectionStyles.row}
        ItemSeparatorComponent={() => <View style={mediaCarouselSectionStyles.rowSeparator} />}
        keyExtractor={(item) => ('id' in item ? item.id : String(item))}
        renderItem={({ item }) =>
          loading ? (
            <ThemedView type="backgroundSelected" style={skeletonStyle} />
          ) : (
            <Pressable
              onPress={() =>
                router.push({
                  pathname: '/media/[id]',
                  params: { id: item.id, title: item.title },
                })
              }>
              <CardComponent item={item} />
            </Pressable>
          )
        }>
      </FlashList>
    </View>
  );
}
