# GFM harness — react-native-enriched-markdown (macOS fork)

> [!TIP]
> this file exercises GFM features **supported by the library fork**.
> compare against the **GFM Reference** tab for the unmodified original.

## Table of Contents
- [Headings](#headings)
- [Paragraphs & Line Breaks](#paragraphs--line-breaks)
- [Emphasis](#emphasis)
- [Links & Autolinks](#links--autolinks)
- [Images](#images)
- [Blockquotes](#blockquotes)
- [Lists](#lists)
- [Task Lists](#task-lists)
- [Tables](#tables)
- [Code & Syntax Highlighting](#code--syntax-highlighting)
- [Diff & Patch Blocks](#diff--patch-blocks)
- [Footnotes](#footnotes)
- [Emoji & Kaomoji](#emoji--kaomoji)
- [Mentions, Issues, PRs, SHAs](#mentions-issues-prs-shas)
- [HTML in Markdown](#html-in-markdown)
- [Admonitions (Callouts)](#admonitions-callouts)
- [Details / Summary (Collapsible)](#details--summary-collapsible)
- [Mathematics (KaTeX)](#mathematics-katex)
- [Diagrams (Mermaid)](#diagrams-mermaid)
- [Escapes & Entities](#escapes--entities)
- [Horizontal Rules](#horizontal-rules)
- [Anchors & Heading IDs](#anchors--heading-ids)
- [Definition List (GitHub may change)](#definition-list-github-may-change)
- [Miscellaneous](#miscellaneous)
- [Reference Definitions](#reference-definitions)

---

## Headings

> [!NOTE]
> all heading levels render correctly. anchor links from the TOC above also work.

# H1
## H2
### H3
#### H4
##### H5
###### H6

Trailing hashes are OK:
### Heading with trailing hashes ###

## Paragraphs & Line Breaks

> [!NOTE]
> paragraphs render correctly. line break tags are converted via JS preprocessing.

A normal paragraph. This sentence ends with two spaces to force a line break.
This is the next line.

Single newline without two spaces does **not** break; you usually need two spaces or `<br>`.<br>Like this.

## Emphasis

> [!NOTE]
> all emphasis types supported. mark, sub, sup, and u tags are rendered via PUA marker preprocessing. when underline flag is enabled, double underscores render as underline — use double asterisks for bold.

*Italic* _Italic also_
**Bold** **Bold also**
***Bold & Italic***
~~Strikethrough~~
**Bold with ~~strikethrough~~ inside**

__Underline__ (via md4cFlags.underline)
<u>Underline (HTML)</u>

<mark>Marked/Highlighted</mark>
H<sub>2</sub>O with <sub>subscript</sub>, and E = mc<sup>2</sup> with <sup>superscript</sup>.

## Links & Autolinks

> [!WARNING]
> links render and are clickable. cosmetic refinements deferred — cursor shows I-beam instead of pointing hand on some elements.

Inline: [GitHub](https://github.com "GitHub Home")
Reference: [Example][example-ref] and [Relative link to README](./README.md)
Autolink literal: https://example.com and www.example.org (GFM autolink)
Angle-bracket autolink: <mailto:octocat@example.com>
Escaped brackets: \[literal brackets\]

Link with title on image: [![Yaktocat](https://octodex.github.com/images/yaktocat.png "Octodex")](https://octodex.github.com/)

## Images

> [!NOTE]
> markdown images are fully supported. **inline** images render at text-height (matching GitHub). **block** images (own line) render at natural size, clamped to container width. HTML img tags are converted to markdown images with width/height preserved via URL fragment encoding.

Inline image: ![Octocat](https://github.githubassets.com/images/icons/emoji/octocat.png)
Reference image (inline): ![Yaktocat][yaktocat]

Block image (own line):

![Yaktocat][yaktocat]

HTML image with width attribute:

<img alt="Octocat" src="https://octodex.github.com/images/yaktocat.png" width="120" />

## Blockquotes

> [!NOTE]
> blockquotes render correctly, including nesting, lists, and code blocks inside.

> Blockquotes can contain paragraphs,
> lists, and code.
>
> - A list item
> - Another item
>
> > Nested blockquote
>
> ```bash
> echo "Fenced code inside a quote"
> ```

## Lists

> [!NOTE]
> unordered, ordered, and nested lists all render correctly.

Unordered (mixing markers `-`, `*`, `+`):

- Item A
  - Nested A.1
    - Nested A.1.a
* Item B
+ Item C

Ordered (custom start index and nesting):

42. Forty-two
43. Forty-three
    1. Sub-one
    2. Sub-two
0. Zero (auto-numbered as 44 on GitHub)

List with paragraphs and code:

1. This item has a paragraph.

   Additional indented paragraph.

   ```js
   console.log("Code in a list item");
   ```

## Task Lists

> [!NOTE]
> task lists render correctly (read-only — not interactive).

- [ ] Top-level unchecked
- [x] Top-level checked
- [ ] Nested tasks
  - [ ] Child 1
  - [x] Child 2
    - [ ] Grandchild
- [ ] _Task with **emphasis** and [link](#links--autolinks)_

## Tables

> [!NOTE]
> tables render correctly with alignment, inline code, bold, and links.

Basic:

| Animal | Sound |
|-------:|:-----:|
| Cat    | Meow  |
| Dog    | Bark  |
| 🐮     | Moo   |

Aligned, inline code & breaks:

| Column A         | Column B        | Column C |
|:-----------------|:----------------|---------:|
| `code`           | **bold**        |      123 |
| line 1<br>line 2 | [link](#tables) |     3.14 |

## Code & Syntax Highlighting

> [!NOTE]
> inline code, indented blocks, and fenced blocks with language hints all render correctly.

Inline `code` and `` `backticks in code` ``.

Indented code block (4 spaces):

    $ echo "Hello from an indented code block"
    $ uname -a

Fenced code block with language hint:

```bash
# Bash / shell
set -euxo pipefail
echo "Hello"
```

```javascript
// JavaScript
function greet(name) {
  console.log(`Hello, ${name}!`);
}
greet("World");
```

```python
def fib(n: int) -> int:
    a, b = 0, 1
    for _ in range(n):
        a, b = b, a + b
    return a
```

Fences with backticks *inside* (use tildes outside):

~~~~
```
Literal triple-backticks inside a code fence.
```
~~~~

## Diff & Patch Blocks

> [!TIP]
> TBD — diff/patch syntax highlighting not yet validated.

## Footnotes

> [!TIP]
> TBD — footnote rendering not yet validated.

## Emoji & Kaomoji

> [!WARNING]
> unicode emoji render correctly. shortcode expansion (`:tada:` → 🎉) is not supported — the library renders shortcodes as literal text.

Unicode emoji: 🎉 🚀 👍 ⚠️ ✨
Kaomoji: (╯°□°）╯︵ ┻━┻  ┬─┬ ノ( ゜-゜ノ)

## Mentions, Issues, PRs, SHAs

> [!IMPORTANT]
> TBD — these are GitHub-specific features that require repo context. not applicable to a standalone renderer.

## HTML in Markdown

> [!WARNING]
> the library sets MD_FLAG_NOHTML, so raw HTML renders as literal text. supported tags (mark, sub, sup, u, br, img) are preprocessed via PUA markers. not yet supported: kbd, ins, del, abbr, details, summary.

Supported:
- <u>Underline via HTML</u>
- <mark>Highlighted text</mark>
- H<sub>2</sub>O and E = mc<sup>2</sup>
- Line break via `<br>`:<br>new line here
- Image via `<img>`: <img alt="Octocat" src="https://octodex.github.com/images/yaktocat.png" width="80" />

Not yet supported (renders as literal text):
- Keyboard keys: <kbd>Ctrl</kbd> + <kbd>C</kbd>
- Inserted/Deleted: <ins>added</ins> and <del>deleted</del>
- Abbreviation: <abbr title="GitHub Flavored Markdown">GFM</abbr>

## Admonitions (Callouts)

> [!NOTE]
> all five GitHub callout types are fully supported with coloured borders, backgrounds, and SF Symbol icons. custom labels for i18n are available via `admonitionLabels` prop.

> [!NOTE]
> This is a **Note** callout.

> [!TIP]
> This is a **Tip** callout.

> [!IMPORTANT]
> This is an **Important** callout.

> [!WARNING]
> This is a **Warning** callout.

> [!CAUTION]
> This is a **Caution** callout.

## Details / Summary (Collapsible)

> [!IMPORTANT]
> TBD — `<details>` and `<summary>` render as literal text (MD_FLAG_NOHTML). would require native collapsible view implementation.

## Mathematics (KaTeX)

> [!IMPORTANT]
> TBD — would require a separate KaTeX rendering engine.

## Diagrams (Mermaid)

> [!IMPORTANT]
> TBD — would require a separate Mermaid rendering engine.

## Escapes & Entities

> [!TIP]
> TBD — escape and entity rendering not yet validated.

## Horizontal Rules

> [!NOTE]
> horizontal rules render correctly.

---
***
___

## Anchors & Heading IDs

> [!NOTE]
> GitHub-style heading slug anchors are supported. in-document scrolling works via the library's `scrollToAnchor` implementation.

Link back to [the top](#gfm-harness--react-native-enriched-markdown-macos-fork).

## Definition List (GitHub may change)

> [!IMPORTANT]
> TBD — definition lists are not a standard GFM feature. GitHub support may evolve.

## Miscellaneous

- HTML comment (won't render): <!-- This is a comment -->
- URL in code shouldn't autolink: `https://not-a-link.example`

> [!NOTE]
> HTML comments are stripped automatically when `flavor="github"`.

---

## Reference Definitions

[example-ref]: https://example.com "Example Domain"
[yaktocat]: https://octodex.github.com/images/yaktocat.png "The Yaktocat"
