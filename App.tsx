import {ScrollView, StyleSheet, useColorScheme, View} from 'react-native';
import {EnrichedMarkdownText} from 'react-native-enriched-markdown';

const SAMPLE_MARKDOWN = `# Hello from macOS!

This is **react-native-enriched-markdown** running on **macOS** via react-native-macos.

## Features

- **Bold text** and *italic text*
- ~~Strikethrough~~
- [Links](https://github.com)
- Inline \`code\` spans

### Code Block

\`\`\`typescript
const greeting = "Hello, macOS!";
console.log(greeting);
\`\`\`

### Blockquote

> This is a blockquote.
> It can span multiple lines.

### Ordered List

1. First item
2. Second item
3. Third item

---

That's it! The port is working.
`;

const darkMarkdownStyle = {
  paragraph: {color: '#E5E7EB'},
  h1: {color: '#F9FAFB'},
  h2: {color: '#F9FAFB'},
  h3: {color: '#F9FAFB'},
  h4: {color: '#F9FAFB'},
  h5: {color: '#D1D5DB'},
  h6: {color: '#9CA3AF'},
  blockquote: {
    color: '#9CA3AF',
    borderColor: '#4B5563',
    backgroundColor: '#1F2937',
  },
  list: {color: '#E5E7EB', bulletColor: '#9CA3AF', markerColor: '#9CA3AF'},
  codeBlock: {
    color: '#F3F4F6',
    backgroundColor: '#111827',
    borderColor: '#374151',
  },
  link: {color: '#60A5FA'},
  strikethrough: {color: '#6B7280'},
  underline: {color: '#E5E7EB'},
  code: {
    color: '#F87171',
    backgroundColor: '#2D1B1E',
    borderColor: '#4B2023',
  },
  thematicBreak: {color: '#374151'},
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

  return (
    <View style={[styles.container, isDarkMode && styles.containerDark]}>
      <ScrollView contentContainerStyle={styles.content}>
        <EnrichedMarkdownText
          markdown={SAMPLE_MARKDOWN}
          markdownStyle={isDarkMode ? darkMarkdownStyle : undefined}
          style={styles.markdown}
        />
      </ScrollView>
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
  content: {
    padding: 24,
  },
  markdown: {
    flex: 1,
  },
});

export default App;
