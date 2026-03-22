import { useCallback, useState } from 'react';
import {
  Alert,
  Linking,
  Pressable,
  StyleSheet,
  Text,
  useColorScheme,
  View,
} from 'react-native';
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

// Loaded on the fly via md-transformer — raw string imports
import testMarkdown from './testdata/Test Markdown File.md';
import gfmHarness from './testdata/gfm-harness.md';
import gfmReference from './testdata/gfm-reference.md';
import gruberSyntax from './testdata/Markdown Syntax - John Gruber.markdown';

const TEST_FILES = [
  { label: 'GFM Reference', content: gfmReference },
  { label: 'GFM Harness', content: gfmHarness },
  { label: 'Syntax Test', content: testMarkdown },
  { label: 'Gruber Syntax', content: gruberSyntax },
];

const lightMarkdownStyle = {
  blockquote: {
    borderColor: '#d0d7de',
    backgroundColor: '#f6f8fa',
  },
  // strikethrough: { color: '#9CA3AF' },
  strikethrough: { color: '#1f2937' },
  underline: { color: '#1F2937' },
  image: { height: 300, borderRadius: 8, marginTop: 8, marginBottom: 16 },
  inlineImage: { size: 20 },
};

const darkMarkdownStyle = {
  paragraph: { color: '#E5E7EB' },
  h1: { color: '#F9FAFB' },
  h2: { color: '#F9FAFB' },
  h3: { color: '#F9FAFB' },
  h4: { color: '#F9FAFB' },
  h5: { color: '#D1D5DB' },
  h6: { color: '#9CA3AF' },
  blockquote: {
    color: '#9CA3AF',
    borderColor: '#3d444d',
    backgroundColor: '#151b23',
  },
  list: { color: '#E5E7EB', bulletColor: '#9CA3AF', markerColor: '#9CA3AF' },
  codeBlock: {
    color: '#F3F4F6',
    backgroundColor: '#111827',
    borderColor: '#374151',
  },
  link: { color: '#60A5FA' },
  // strikethrough: { color: '#6B7280' },
  strikethrough: { color: '#e5e7eb' },
  underline: { color: '#E5E7EB' },
  code: {
    color: '#F87171',
    backgroundColor: '#2D1B1E',
    borderColor: '#4B2023',
  },
  thematicBreak: { color: '#374151' },
  image: { height: 300, borderRadius: 8, marginTop: 8, marginBottom: 16 },
  inlineImage: { size: 20 },
  table: {
    color: '#E5E7EB',
    headerBackgroundColor: '#1F2937',
    headerTextColor: '#F9FAFB',
    rowEvenBackgroundColor: '#111827',
    rowOddBackgroundColor: '#1A1A2E',
    borderColor: '#374151',
  },
};

function App() {
  const isDarkMode = useColorScheme() === 'dark';
  const [activeIndex, setActiveIndex] = useState(0);

  const handleLinkPress = useCallback(({ url }: { url: string }) => {
    if (url.startsWith('#')) {
      // Anchor scrolling handled natively by the library
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      Linking.openURL(url).catch((err) =>
        Alert.alert('Failed to open link', err.message),
      );
    } else {
      console.log(`Unhandled link: ${url}`);
    }
  }, []);

  return (
    <View style={[styles.container, isDarkMode && styles.containerDark]}>
      <View style={[styles.tabBar, isDarkMode && styles.tabBarDark]}>
        {TEST_FILES.map((file, i) => (
          <Pressable
            key={file.label}
            onPress={() => setActiveIndex(i)}
            style={[
              styles.tab,
              isDarkMode && styles.tabDark,
              activeIndex === i && styles.tabActive,
              activeIndex === i && isDarkMode && styles.tabActiveDark,
            ]}
          >
            <Text
              style={[
                styles.tabText,
                isDarkMode && styles.tabTextDark,
                activeIndex === i && styles.tabTextActive,
              ]}
            >
              {file.label}
            </Text>
          </Pressable>
        ))}
      </View>
      <View style={styles.tabContent}>
        {TEST_FILES.map((file, i) => (
          <EnrichedMarkdownText
            key={`md-${i}`}
            markdown={file.content}
            markdownStyle={isDarkMode ? darkMarkdownStyle : lightMarkdownStyle}
            flavor="github"
            md4cFlags={{ underline: true }}
            contentInset={{ left: 16, right: 16, top: 16 }}
            onLinkPress={handleLinkPress}
            style={[
              styles.markdownTab,
              { zIndex: activeIndex === i ? 1 : 0, opacity: activeIndex === i ? 1 : 0 },
            ]}
            pointerEvents={activeIndex === i ? 'auto' : 'none'}
          />
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  containerDark: {
    backgroundColor: '#1a1a1a',
  },
  tabBar: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: '#e5e7eb',
    backgroundColor: '#f9fafb',
    paddingHorizontal: 8,
    paddingTop: 8,
  },
  tabBarDark: {
    borderBottomColor: '#374151',
    backgroundColor: '#111827',
  },
  tab: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    marginRight: 4,
    borderTopLeftRadius: 8,
    borderTopRightRadius: 8,
  },
  tabDark: {},
  tabActive: {
    backgroundColor: '#ffffff',
    borderWidth: 1,
    borderBottomWidth: 0,
    borderColor: '#e5e7eb',
  },
  tabActiveDark: {
    backgroundColor: '#1a1a1a',
    borderColor: '#374151',
  },
  tabText: {
    fontSize: 13,
    color: '#6b7280',
  },
  tabTextDark: {
    color: '#9ca3af',
  },
  tabTextActive: {
    color: '#111827',
    fontWeight: '600',
  },
  content: {
    padding: 24,
    paddingBottom: 48,
  },
  tabContent: {
    flex: 1,
    position: 'relative',
  },
  markdownTab: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
});

export default App;
