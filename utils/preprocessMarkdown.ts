/**
 * Lightweight JS preprocessor for GitHub-flavoured Markdown extensions
 * not yet supported by react-native-enriched-markdown's md4c parser.
 *
 * Intended as a temporary bridge until native support lands.
 * Keep transforms simple and non-destructive — they run on every render.
 */

const ADMONITION_TYPES: Record<string, { label: string }> = {
  NOTE: { label: 'Note' },
  TIP: { label: 'Tip' },
  IMPORTANT: { label: 'Important' },
  WARNING: { label: 'Warning' },
  CAUTION: { label: 'Caution' },
};

/**
 * Convert GitHub-style admonitions into prefixed blockquotes.
 *
 * Input:
 *   > [!NOTE]
 *   > This is a note.
 *
 * Output:
 *   > **Note**
 *   >
 *   > This is a note.
 */
function transformAdmonitions(md: string): string {
  const pattern = /^(>\s*)\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$/gm;

  return md.replace(pattern, (_match, prefix: string, type: string) => {
    const admonition = ADMONITION_TYPES[type];
    if (!admonition) return _match;
    return `${prefix}**${admonition.label}**\n${prefix}`;
  });
}

/**
 * Apply all preprocessor transforms to raw markdown.
 */
export function preprocessMarkdown(md: string): string {
  return transformAdmonitions(md);
}
