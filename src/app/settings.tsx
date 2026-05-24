import { router } from 'expo-router';
import { Pressable, ScrollView, View } from 'react-native';
import { Database, Globe, Palette, Server } from 'lucide-react-native';

import { ListRowItem } from '@/components/list-row-item';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useAppTheme } from '@/hooks/use-app-theme';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { createSettingsScreenStyles } from '@/styles/settings-screen.styles';
import type { Locale } from '@/i18n/types';

const LANGUAGES: { code: Locale; name: string }[] = [
  { code: 'en', name: 'English' },
  { code: 'ru', name: 'Русский' },
  { code: 'uk', name: 'Українська' },
  { code: 'be', name: 'Беларуская' },
  { code: 'ro', name: 'Română' },
];

export default function SettingsScreen() {
  const theme = useTheme();
  const { resolvedTheme, toggleTheme } = useAppTheme();
  const styles = createSettingsScreenStyles(theme);
  const { copy, locale } = useI18n();
  const isDarkTheme = resolvedTheme === 'dark';

  return (
    <ThemedView style={styles.container}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.content}>
        <View style={styles.section}>
          <ThemedText style={styles.sectionTitle}>{copy.settings.common}</ThemedText>

          <ListRowItem
            title={copy.settings.source}
            value={copy.settings.defaultSource}
            onPress={() => router.push('/settings/source')}
            showChevron
            leftAccessory={
              <View style={styles.iconWrapper}>
                <Server size={20} color={theme.textSecondary} />
              </View>
            }
          />

          <ListRowItem
            title={copy.settings.language}
            value={LANGUAGES.find((l) => l.code === locale)?.name}
            onPress={() => router.push('/settings/language')}
            showChevron
            leftAccessory={
              <View style={styles.iconWrapper}>
                <Globe size={20} color={theme.textSecondary} />
              </View>
            }
          />
        </View>

        <View style={styles.section}>
          <ThemedText style={styles.sectionTitle}>{copy.settings.appearance}</ThemedText>
          
          <View style={styles.settingItem}>
            <View style={styles.settingLeft}>
              <View style={styles.iconWrapper}>
                <Palette size={20} color={theme.textSecondary} />
              </View>
              <ThemedText style={styles.settingLabel}>{copy.settings.darkTheme}</ThemedText>
            </View>
            <Pressable 
              style={[styles.toggle, isDarkTheme && styles.toggleActive]}
              onPress={toggleTheme}>
              <View style={[styles.toggleThumb, isDarkTheme && styles.toggleThumbActive]} />
            </Pressable>
          </View>
        </View>

        <View style={styles.section}>
          <ThemedText style={styles.sectionTitle}>{copy.settings.storage}</ThemedText>
          
          <ListRowItem
            title={copy.settings.clearCache}
            subtitle={copy.settings.clearCacheDesc}
            value="0 МБ"
            onPress={() => console.log('Clear cache')}
            leftAccessory={
              <View style={styles.iconWrapper}>
                <Database size={20} color={theme.textSecondary} />
              </View>
            }
          />
        </View>
      </ScrollView>
    </ThemedView>
  );
}
