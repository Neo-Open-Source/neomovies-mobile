import { StyleSheet } from 'react-native';

import { Radius, Spacing } from '@/constants/theme';

type ThemePalette = {
  backgroundElement: string;
  textSecondary: string;
};

export function createFavoritesScreenStyles(theme: ThemePalette) {
  return StyleSheet.create({
    emptyWrap: {
      flex: 1,
      minHeight: 360,
      alignItems: 'center',
      justifyContent: 'center',
      paddingHorizontal: Spacing.four,
      gap: Spacing.three,
    },
    emptyIconWrap: {
      width: 56,
      height: 56,
      borderRadius: 999,
      backgroundColor: theme.backgroundElement,
      alignItems: 'center',
      justifyContent: 'center',
    },
    emptyText: {
      textAlign: 'center',
      color: theme.textSecondary,
      maxWidth: 260,
      lineHeight: 22,
      fontSize: 15,
      fontWeight: '500',
    },
  });
}
