import { ScrollView, View } from 'react-native';
import { Code, Heart } from 'lucide-react-native';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useTheme } from '@/hooks/use-theme';
import { createCreditsScreenStyles } from '@/styles/credits-screen.styles';

const LIBRARIES = [
  { name: 'React Native', description: 'Mobile framework' },
  { name: 'Expo', description: 'Development platform' },
  { name: 'Expo Router', description: 'File-based routing' },
  { name: 'Expo Image', description: 'Optimized images' },
  { name: 'Lucide React Native', description: 'Icon library' },
  { name: 'React Native Reanimated', description: 'Animations' },
];

export default function CreditsScreen() {
  const theme = useTheme();
  const styles = createCreditsScreenStyles(theme);

  return (
    <ThemedView style={styles.container}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.content}>
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Code size={20} color={theme.accent} />
            <ThemedText style={styles.sectionTitle}>Используемые библиотеки</ThemedText>
          </View>
          
          <View style={styles.creditsCard}>
            {LIBRARIES.map((lib, index) => (
              <View key={lib.name} style={[styles.creditItem, index === LIBRARIES.length - 1 && styles.creditItemLast]}>
                <ThemedText style={styles.creditName}>{lib.name}</ThemedText>
                <ThemedText style={styles.creditDescription}>{lib.description}</ThemedText>
              </View>
            ))}
          </View>
        </View>

        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Heart size={20} color={theme.accent} />
            <ThemedText style={styles.sectionTitle}>Команда разработки</ThemedText>
          </View>
          
          <View style={styles.creditsCard}>
            <View style={styles.creditItem}>
              <ThemedText style={styles.creditName}>Neo Team</ThemedText>
              <ThemedText style={styles.creditDescription}>С любовью для сообщества</ThemedText>
            </View>
          </View>
        </View>
      </ScrollView>
    </ThemedView>
  );
}
