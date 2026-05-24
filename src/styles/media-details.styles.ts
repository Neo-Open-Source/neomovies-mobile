import { StyleSheet } from 'react-native';

import { Radius, Spacing } from '@/constants/theme';

type ThemePalette = {
  accent: string;
  accentMuted: string;
  backgroundElement: string;
  border: string;
  text: string;
  textSecondary: string;
};

export function createMediaDetailsStyles(theme: ThemePalette) {
  return StyleSheet.create({
    container: { flex: 1 },
    content: {
      paddingHorizontal: Spacing.three,
      paddingBottom: 110,
      gap: Spacing.three,
    },
    heroCard: {
      borderRadius: Radius.lg,
      overflow: 'hidden',
      backgroundColor: theme.backgroundElement,
      borderWidth: 1,
      borderColor: theme.border,
      minHeight: 230,
    },
    heroImage: {
      width: '100%',
      height: 230,
    },
    logoWrap: {
      position: 'absolute',
      left: Spacing.three,
      right: Spacing.three,
      bottom: Spacing.three,
      alignItems: 'flex-start',
      justifyContent: 'flex-end',
    },
    logo: {
      width: 190,
      height: 62,
    },
    logoHidden: {
      opacity: 0,
    },
    title: {
      fontSize: 28,
      lineHeight: 34,
      fontWeight: '700',
    },
    metaRow: {
      flexDirection: 'row',
      flexWrap: 'wrap',
      gap: Spacing.two,
    },
    metaItem: {
      fontSize: 14,
      lineHeight: 20,
      color: theme.textSecondary,
    },
    genresRow: {
      flexDirection: 'row',
      flexWrap: 'wrap',
      gap: Spacing.one,
    },
    genreChip: {
      borderWidth: 1,
      borderColor: theme.border,
      backgroundColor: theme.backgroundElement,
      borderRadius: 999,
      paddingHorizontal: Spacing.two,
      paddingVertical: Spacing.one,
    },
    genreText: {
      fontSize: 12,
      lineHeight: 16,
      color: theme.textSecondary,
      fontWeight: '600',
    },
    description: {
      fontSize: 15,
      lineHeight: 22,
      color: theme.textSecondary,
    },
    actionsRow: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: Spacing.two,
    },
    watchButton: {
      flex: 1,
      minHeight: 48,
      borderRadius: Radius.md,
      backgroundColor: theme.accent,
      alignItems: 'center',
      justifyContent: 'center',
      paddingHorizontal: Spacing.three,
    },
    watchButtonContent: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'center',
      gap: Spacing.one,
    },
    watchButtonText: {
      color: '#FFFFFF',
      fontSize: 16,
      lineHeight: 20,
      fontWeight: '700',
    },
    iconButton: {
      width: 48,
      height: 48,
      borderRadius: Radius.md,
      borderWidth: 1,
      borderColor: theme.border,
      backgroundColor: theme.accentMuted,
      alignItems: 'center',
      justifyContent: 'center',
    },
    skeleton: {
      borderRadius: Radius.md,
      height: 22,
    },
    skeletonHero: {
      borderRadius: Radius.lg,
      height: 230,
    },
  });
}
