import { router } from 'expo-router';
import { useState } from 'react';
import { ScrollView, View } from 'react-native';
import { Server } from 'lucide-react-native';

import { SelectionItem } from '@/components/selection-item';
import { ThemedView } from '@/components/themed-view';
import { useI18n } from '@/i18n';
import { useTheme } from '@/hooks/use-theme';
import { createSourceScreenStyles } from '@/styles/source-screen.styles';

type Source = 'default' | 'alternative';

export default function SourceSelectionScreen() {
  const theme = useTheme();
  const { copy } = useI18n();
  const styles = createSourceScreenStyles(theme);
  const [selectedSource, setSelectedSource] = useState<Source>('default');
  const sources: { id: Source; name: string; description: string }[] = [
    {
      id: 'default',
      name: copy.settings.sourceDefaultTitle,
      description: copy.settings.sourceDefaultDesc,
    },
    {
      id: 'alternative',
      name: copy.settings.sourceAlternativeTitle,
      description: copy.settings.sourceAlternativeDesc,
    },
  ];

  const handleSelectSource = (id: Source) => {
    if (id === 'alternative') return; // Пока заглушка
    setSelectedSource(id);
    setTimeout(() => {
      router.back();
    }, 200);
  };

  return (
    <ThemedView style={styles.container}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.content}>
        {sources.map((source) => {
          const isSelected = selectedSource === source.id;
          const isDisabled = source.id === 'alternative';
          return (
            <SelectionItem
              key={source.id}
              title={source.name}
              subtitle={source.description}
              selected={isSelected}
              disabled={isDisabled}
              onPress={() => handleSelectSource(source.id)}
              leftAccessory={
                <View style={[styles.iconWrapper, isDisabled && styles.iconWrapperDisabled]}>
                  <Server size={20} color={isDisabled ? theme.textMuted : theme.textSecondary} />
                </View>
              }
            />
          );
        })}
      </ScrollView>
    </ThemedView>
  );
}
