import { ScrollView, View } from 'react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useTheme } from '@/hooks/use-theme';
import { useI18n } from '@/i18n';
import { createStaticPageStyles } from '@/styles/static-page.styles';

export default function UpdatesScreen() {
  const styles = createStaticPageStyles(useTheme());
  const { copy } = useI18n();

  return (
    <ThemedView style={styles.container}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.content}>
        <View style={styles.card}>
          <ThemedText style={styles.text}>
            {copy.profile.updates} (заглушка). История изменений и релиз-ноты.
          </ThemedText>
        </View>
      </ScrollView>
    </ThemedView>
  );
}
