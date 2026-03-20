# enriched-markdown integration notes

Library-specific quirks and feature status for [react-native-enriched-markdown](https://github.com/LeslieOA/react-native-enriched-markdown) (fork).

## md4cFlags

The harness enables `md4cFlags={{ underline: true }}` which changes how `__double underscores__` are interpreted:

| flag state | `__text__` renders as |
|---|---|
| `underline: false` (default) | **bold** (same as `**text**`) |
| `underline: true` | underline |

When `underline: true` is set, use `**text**` for bold — not `__text__`.

## strikethrough line colour

The library's default strikethrough line colour blends with the text. Override per colour scheme:

```tsx
// light
strikethrough: { color: '#9CA3AF' }

// dark
strikethrough: { color: '#6B7280' }
```

## GFM HTML tags — support status

The library sets `MD_FLAG_NOHTML` in the md4c parser, so raw HTML tags render as plain text. To work around this, the library's JS preprocessor replaces supported HTML tags with PUA (Private Use Area) Unicode markers before parsing. After md4c produces the `NSAttributedString`, a native post-processor scans for the PUA pairs and applies the corresponding attributes (highlight, baseline offset, font scaling).

| syntax | status | notes |
|---|---|---|
| `~~strikethrough~~` | supported | native GFM strikethrough |
| `__underline__` | supported | requires `md4cFlags.underline: true` |
| `<mark>` | supported | JS preprocessing → PUA markers → native background highlight |
| `<sub>` / `<sup>` | supported | JS preprocessing → PUA markers → native baseline offset + scaled font |
| `<u>` | not needed | use `__text__` with underline flag instead |

## admonitions (GitHub callouts)

`> [!NOTE]`, `> [!TIP]`, etc. are preprocessed in the library's JS layer and rendered natively with coloured borders, backgrounds, and SF Symbol icons.

Custom labels for i18n:

```tsx
<EnrichedMarkdownText
  flavor="github"
  admonitionLabels={{ NOTE: 'Nota', TIP: 'Consejo' }}
/>
```

## HTML comments

`<!-- ... -->` comments are stripped automatically when `flavor="github"`.

## bob build

The library compiles `src/` → `lib/module/` via `react-native-builder-bob`. Metro resolves the compiled output, not the TypeScript source. After editing library source files, recompile:

```sh
cd ../react-native-enriched-markdown-macos && npx bob build
```

Native (Objective-C/C++) changes require a full rebuild (`npx react-native run-macos`).
