# monorepo integration prompt

paste this into Claude Code when setting up `react-native-enriched-markdown` in your Workspace monorepo.

---

I need to integrate `react-native-enriched-markdown` (a local fork) into this monorepo for macOS rendering. Here's the context:

## library location

The library fork is at `../react-native-enriched-markdown/` (relative to this app). It's on branch `feat/macos-support-pr163`. Repo: https://github.com/LeslieOA/react-native-enriched-markdown

## what the library provides

A React Native component that renders GitHub Flavoured Markdown natively on macOS (and iOS). Key features of this fork:
- GFM tables, task lists, admonitions/callouts with SF Symbol icons
- Inline HTML support: `<mark>`, `<sub>`, `<sup>`, `<u>`, `<br>`, `<img>` (with width/height)
- In-document anchor scrolling
- Block images at natural size clamped to container width
- `contentInset` prop for scroll view padding (scrollbar stays flush)
- Dark mode via `markdownStyle` prop

## setup steps needed

1. **metro.config.js** — configure `watchFolders`, `extraNodeModules`, `nodeModulesPaths`, and `blockList` to resolve the local library. Block the library's own `react` and `react-native` node_modules to avoid duplicate React errors.

2. **bob build** — the library uses `react-native-builder-bob`. Run `cd ../react-native-enriched-markdown && npx bob build` to compile `src/` → `lib/module/`. Metro resolves the compiled output.

3. **CocoaPods** — run `cd macos && LANG=en_US.UTF-8 bundle exec pod install && cd ..` after setup. The library's native files are picked up automatically via `source_files` glob.

## component usage

```tsx
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';

<EnrichedMarkdownText
  markdown={content}
  flavor="github"
  md4cFlags={{ underline: true }}
  contentInset={{ left: 16, right: 16, top: 16 }}
  markdownStyle={isDarkMode ? darkMarkdownStyle : lightMarkdownStyle}
  onLinkPress={({ url }) => {
    if (url.startsWith('http')) Linking.openURL(url);
  }}
/>
```

## key notes

- `flavor="github"` is required for GFM features (tables, admonitions, task lists, anchor scrolling)
- `md4cFlags={{ underline: true }}` makes `__text__` render as underline — use `**text**` for bold
- the component wraps itself in an `NSScrollView` on macOS — do NOT wrap in a `ScrollView`
- after editing library JS files: `cd ../react-native-enriched-markdown && npx bob build`
- after editing library native (ObjC/C++) files: full rebuild with `npx react-native run-macos`

## reference

- harness repo: https://github.com/LeslieOA/enriched-markdown-macos-harness (working example)
- library docs: `../react-native-enriched-markdown/docs/MACOS.md`
- style reference: `../react-native-enriched-markdown/docs/STYLES.md`
