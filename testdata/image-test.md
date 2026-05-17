# Image Rendering Test

Baseline for verifying GFM/CommonMark image behaviour.

---

## 1. Inline images (should render at text height)

Text before ![Octocat](https://github.githubassets.com/images/icons/emoji/octocat.png) text after.

Multiple inline: ![Octocat](https://github.githubassets.com/images/icons/emoji/octocat.png) and ![Yaktocat](https://octodex.github.com/images/yaktocat.png) on the same line.

## 2. Block image (should render at natural size, clamped to viewport width)

![Yaktocat](https://octodex.github.com/images/yaktocat.png)

## 3. Image inside a link, inline (should render at text height)

Link with image: [![Yaktocat](https://octodex.github.com/images/yaktocat.png "Octodex")](https://octodex.github.com/)

## 4. Image inside a link, block (should render at natural size, clamped)

[![Yaktocat](https://octodex.github.com/images/yaktocat.png "Octodex")](https://octodex.github.com/)

## 5. HTML img with explicit width (should render at 120px wide)

<img alt="Octocat" src="https://octodex.github.com/images/yaktocat.png" width="120" />

## 6. HTML img with explicit width and height (should render at exactly 80x80)

<img alt="Octocat" src="https://octodex.github.com/images/yaktocat.png" width="80" height="80" />

## 7. Small image, block (should render at natural size, NOT stretched to viewport)

![Emoji](https://github.githubassets.com/images/icons/emoji/octocat.png)

## 8. Large image, block (should clamp to viewport width, preserve aspect ratio)

![Yaktocat](https://octodex.github.com/images/yaktocat.png)

## 9. Reference-style images

Inline ref: text ![Yaktocat][yak] more text.

Block ref:

![Yaktocat][yak]

[yak]: https://octodex.github.com/images/yaktocat.png "Yaktocat"
