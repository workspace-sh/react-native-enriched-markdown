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

## image sizing

The library distinguishes **block** vs **inline** images:

- **Block** — image on its own line (preceded by `\n` or start of text). Scales to container width, preserves aspect ratio.
- **Inline** — image mid-paragraph (text before it on the same line). Fixed square at `inlineImageSize`.

This is a consuming-app concern, not a library bug. If you want a large image, put it on its own line in the markdown source.

Style props via `markdownStyle` (see upstream `STYLES.md`):

```tsx
image: { height: 200, borderRadius: 8, marginTop: 0, marginBottom: 16 },
inlineImage: { size: 20 },
```

No `width` or `aspectRatio` props — block images scale to container width automatically.

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
cd ../react-native-enriched-markdown && npx bob build
```

Native (Objective-C/C++) changes require a full rebuild (`npx react-native run-macos`).

## test files

| tab | file | purpose |
|---|---|---|
| GFM Harness | `testdata/gfm-harness.md` | working file — adapted for library quirks (`__underline__`, PUA markers work) |
| GFM Reference | `testdata/gfm-reference.md` | unmodified original — compare against GitHub rendering |
| Syntax Test | `testdata/Test Markdown File.md` | basic markdown syntax coverage |
| Gruber Syntax | `testdata/Markdown Syntax - John Gruber.markdown` | original Daring Fireball spec |

## known caveats / TODO

| feature | status | notes |
|---|---|---|
| `<br>` | not working | renders as literal text (MD_FLAG_NOHTML). needs PUA preprocessing |
| links / autolinks | working | cosmetic tweaks deferred |
| images (markdown) | working | block images scale to container; inline images are text-height |
| images (HTML `<img>`) | not working | renders as literal text. complex — needs attribute extraction |
| `<kbd>`, `<ins>`, `<del>`, `<abbr>` | not working | would need PUA preprocessing per tag |
| `<details>` / `<summary>` | not working | collapsible sections render as literal text |
| math (KaTeX) | not supported | would require a separate rendering engine |
| mermaid diagrams | not supported | would require a separate rendering engine |
