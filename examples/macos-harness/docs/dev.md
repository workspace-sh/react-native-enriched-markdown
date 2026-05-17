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
| `<u>` | supported | JS preprocessing → PUA markers → native underline attribute |
| `<br>` | supported | JS preprocessing → markdown line break (two trailing spaces + newline) |
| `<img>` | supported | JS preprocessing → markdown image with dimension hints in URL fragment |

## image sizing

the library distinguishes **block** vs **inline** images:

- **block** — image on its own line (preceded by `\n` or start of text). scales to container width, preserves aspect ratio.
- **inline** — image mid-paragraph (text before it on the same line). fixed square at `inlineImageSize`.

this matches GitHub's rendering behaviour — inline images are always text-height regardless of their natural dimensions.

### `<img>` tag dimensions

`<img>` HTML tags are converted to markdown images by the JS preprocessor. explicit `width` and `height` attributes are preserved via URL fragment encoding:

```
<img alt="Cat" src="https://example.com/cat.png" width="120" />
→ ![Cat](https://example.com/cat.png#__enrm_w=120)
```

the native image attachment parses the `__enrm_` fragment, strips it before downloading (fragments are never sent to servers per HTTP spec), and uses the dimensions for rendering. images without explicit dimensions use the library defaults.

### block images — natural size

block images without explicit dimensions render at their **natural size** when narrower than the container, or clamp to container width when wider. aspect ratio is always preserved.

### `image.responsive` flag

opt-in flag for rendering **inline** images at their natural dimensions instead of the fixed `inlineImageSize`:

```tsx
markdownStyle={{
  image: { responsive: true },
}}
```

| `responsive` | inline images | block images |
|---|---|---|
| `false` (default) | fixed at `inlineImageSize` (matches GitHub) | natural size or container width |
| `true` | natural dimensions | natural size or container width |

### style props

```tsx
image: { height: 200, borderRadius: 8, marginTop: 0, marginBottom: 16, responsive: false },
inlineImage: { size: 20 },
```

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
| GFM Harness | `testdata/gfm-harness.md` | working file — adapted for library quirks (see below) |
| GFM Reference | `testdata/gfm-reference.md` | **unmodified original — never edit this file** |
| Syntax Test | `testdata/Test Markdown File.md` | basic markdown syntax coverage |
| Gruber Syntax | `testdata/Markdown Syntax - John Gruber.markdown` | original Daring Fireball spec |

**rule:** `gfm-reference.md` is the ground truth from the original GFM test file. it must stay unmodified so it can be compared 1:1 against GitHub's rendering. all harness-specific adaptations (e.g. `**bold**` instead of `__bold__` when underline flag is on) go in `gfm-harness.md` only.

the harness renders both files as separate tabs so you can see where the library diverges from standard GFM.

## known caveats / TODO

| feature | status | notes |
|---|---|---|
| links / autolinks | working | cosmetic tweaks deferred; cursor shows I-beam instead of pointing hand on hover |
| images (markdown) | working | block = natural/container width; inline = text-height (or `responsive: true`) |
| images (HTML `<img>`) | working | dimensions from `width`/`height` attributes preserved via URL fragment |
| `<br>` | working | converted to markdown line break |
| `<kbd>`, `<ins>`, `<del>`, `<abbr>` | not working | would need PUA preprocessing per tag |
| `<details>` / `<summary>` | not working | collapsible sections render as literal text |
| math (KaTeX) | not supported | would require a separate rendering engine |
| mermaid diagrams | not supported | would require a separate rendering engine |
