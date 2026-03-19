/**
 * Lightweight JS preprocessor for GitHub-flavoured Markdown extensions
 * not yet supported by react-native-enriched-markdown's md4c parser.
 *
 * Intended as a temporary bridge until native support lands.
 * Keep transforms simple and non-destructive — they run on every render.
 */

const ADMONITION_TYPES: Record<string, { emoji: string; label: string }> = {
  NOTE: { emoji: '\u2139\uFE0F', label: 'Note' },
  TIP: { emoji: '\uD83D\uDCA1', label: 'Tip' },
  IMPORTANT: { emoji: '\u2757', label: 'Important' },
  WARNING: { emoji: '\u26A0\uFE0F', label: 'Warning' },
  CAUTION: { emoji: '\uD83D\uDED1', label: 'Caution' },
};

/**
 * Convert GitHub-style admonitions into prefixed blockquotes.
 *
 * Input:
 *   > [!NOTE]
 *   > This is a note.
 *
 * Output:
 *   > **ℹ️ Note**
 *   >
 *   > This is a note.
 */
function transformAdmonitions(md: string): string {
  const pattern = /^(>\s*)\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$/gm;

  return md.replace(pattern, (_match, prefix: string, type: string) => {
    const admonition = ADMONITION_TYPES[type];
    if (!admonition) return _match;
    return `${prefix}**${admonition.emoji} ${admonition.label}**\n${prefix}`;
  });
}

/**
 * Convert GFM tables into code-block-style formatted text.
 *
 * On macOS, the native EnrichedMarkdown multi-segment renderer
 * (used for table segments) has coordinate system issues. This
 * preprocessor converts tables into a readable monospace format
 * so the content stays in EnrichedMarkdownText (single text view).
 *
 * Input:
 *   | Animal | Sound |
 *   |--------|-------|
 *   | Cat    | Meow  |
 *   | Dog    | Bark  |
 *
 * Output:
 *   ```
 *   Animal  Sound
 *   ------  -----
 *   Cat     Meow
 *   Dog     Bark
 *   ```
 */
function transformTables(md: string): string {
  // Match a GFM table: header row, separator row, and one or more data rows
  const tablePattern =
    /^(\|.+\|)\s*\n(\|[\s:|\-]+\|)\s*\n((?:\|.+\|\s*\n?)+)/gm;

  return md.replace(tablePattern, (match) => {
    const lines = match.trim().split('\n');
    if (lines.length < 3) return match;

    // Parse each row into cells
    const parseRow = (line: string): string[] =>
      line
        .replace(/^\|/, '')
        .replace(/\|$/, '')
        .split('|')
        .map((cell) => cell.trim());

    const headerCells = parseRow(lines[0]);
    // lines[1] is the separator — skip it
    const dataRows = lines.slice(2).map(parseRow);

    // Calculate column widths
    const colWidths = headerCells.map((h, i) => {
      const dataMax = dataRows.reduce(
        (max, row) => Math.max(max, (row[i] || '').length),
        0,
      );
      return Math.max(h.length, dataMax);
    });

    // Format header
    const header = headerCells
      .map((h, i) => h.padEnd(colWidths[i]))
      .join('  ');
    const separator = colWidths.map((w) => '-'.repeat(w)).join('  ');
    const rows = dataRows.map((row) =>
      row.map((cell, i) => (cell || '').padEnd(colWidths[i] || 0)).join('  '),
    );

    return '\n```\n' + [header, separator, ...rows].join('\n') + '\n```\n\n';
  });
}

/**
 * Apply all preprocessor transforms to raw markdown.
 */
export function preprocessMarkdown(md: string): string {
  // Only transform admonitions — tables pass through to native
  // EnrichedMarkdown component which renders them with TableContainerView
  return transformAdmonitions(md);
}
