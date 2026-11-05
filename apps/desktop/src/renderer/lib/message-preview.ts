/** A line without block/bold/code markers. */
const clean = (line: string) => line.replace(/^[#>\-* ]+/, '').replaceAll('**', '').replaceAll('`', '')

/** Match the terminal roster: first nonempty line, without block/bold/code markers. */
export function messagePreview(text: string): string {
  const first = text.split(/\r?\n/).map((line) => line.trim()).find(Boolean) ?? ''
  return clean(first)
}

/** The first `max` nonempty lines, without the same markers, for a card's preview. */
export function messagePreviewLines(text: string, max: number): string {
  return text.split(/\r?\n/).map((line) => line.trim()).filter(Boolean).slice(0, max).map(clean).join('\n')
}
