import { router } from 'expo-router';
import { View } from 'react-native';
import Constants from 'expo-constants';
import { Image } from 'expo-image';
import { FileText, RefreshCw, Sparkles } from 'lucide-react-native';
import { FlashList } from '@shopify/flash-list';

import { ListRowItem } from '@/components/list-row-item';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { createAboutScreenStyles } from '@/styles/about-screen.styles';

export default function AboutScreen() {
  const theme = useTheme();
  const styles = createAboutScreenStyles(theme);
  const { copy } = useI18n();
  const appName = Constants.expoConfig?.name || copy.appName;
  const version = Constants.nativeAppVersion || Constants.expoConfig?.version || '—';
  const branch = ((Constants.expoConfig?.extra as { branch?: string; releaseType?: string } | undefined)?.releaseType)
    || ((Constants.expoConfig?.extra as { branch?: string } | undefined)?.branch)
    || (__DEV__ ? 'dev' : 'release');
  const build = Constants.nativeBuildVersion || '—';
  const appIconUri = Constants.expoConfig?.icon || null;
  const appIconSource = appIconUri && /^https?:\/\//.test(appIconUri)
    ? { uri: appIconUri }
    : require('@/assets/icons/splash-icon.png');

  return (
    <ThemedView style={styles.container}>
      <FlashList
        data={[{ id: 'about' }]}
        keyExtractor={(item) => item.id}
        showsVerticalScrollIndicator={false}
        renderItem={() => (
          <View style={styles.content}>
        <View style={styles.centeredIconWrap}>
          <Image source={appIconSource} style={styles.centeredAppIcon} contentFit="cover" />
        </View>
        <ThemedText style={styles.appDescription}>{copy.about.appDescription}</ThemedText>

        <View style={styles.listStack}>
          <ListRowItem
            title={copy.about.checkUpdates}
            subtitle={copy.about.checkUpdatesDesc}
            onPress={() => console.log('Check update')}
            showChevron
            leftAccessory={
              <View style={styles.iconWrapper}>
                <RefreshCw size={18} color={theme.textSecondary} />
              </View>
            }
          />
          <ListRowItem
            title={copy.about.credits}
            subtitle={copy.about.creditsDesc}
            onPress={() => router.push('/credits')}
            showChevron
            leftAccessory={
              <View style={styles.iconWrapper}>
                <Sparkles size={18} color={theme.textSecondary} />
              </View>
            }
          />
          <ListRowItem
            title={copy.about.changelog}
            subtitle={copy.about.changelogDesc}
            onPress={() => router.push('/changelog')}
            showChevron
            leftAccessory={
              <View style={styles.iconWrapper}>
                <FileText size={18} color={theme.textSecondary} />
              </View>
            }
          />
        </View>

        <View style={styles.versionCard}>
          <View style={styles.versionHeader}>
            <ThemedText style={styles.preferenceTitle}>{appName}</ThemedText>
          </View>
          <View style={styles.metaRow}>
            <ThemedText style={styles.metaLabel}>{copy.about.version}</ThemedText>
            <ThemedText style={styles.metaValue}>{version}</ThemedText>
          </View>
          <View style={styles.metaSeparator} />
          <View style={styles.metaRow}>
            <ThemedText style={styles.metaLabel}>{copy.about.branch}</ThemedText>
            <ThemedText style={styles.metaValue}>{branch}</ThemedText>
          </View>
          <View style={styles.metaSeparator} />
          <View style={styles.metaRow}>
            <ThemedText style={styles.metaLabel}>{copy.about.build}</ThemedText>
            <ThemedText style={styles.metaValue}>{build}</ThemedText>
          </View>
        </View>
          </View>
        )}
      />
    </ThemedView>
  );
}
