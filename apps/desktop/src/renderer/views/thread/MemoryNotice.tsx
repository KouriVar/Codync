import { useEffect, useRef, useState } from 'react'
import { Icon } from '../../components/Icon'
import { Text } from '../../components/Text'
import { useTr } from '../../lib/use-language'
import { useStore } from '../../store/context'
import type { MemoryView } from '../../store/memory-store'
import './memory-notice.css'

/**
 * A light hint in the main conversation when this bot's memory gains a fact (C0102): the host bumps
 * `memoryRev` whenever a layer's `MEMORY.md` changes, so the newest line is read back and shown for a
 * few seconds — “记住了：……”. Nothing is posted to the transcript, and it says nothing when a fact is
 * edited or taken out.
 */
export function MemoryNotice({ botId }: { botId: string }) {
  const tr = useTr()
  const store = useStore()
  const bot = store.bots.get(botId)
  const rev = bot?.memoryRev ?? 0
  const lastRev = useRef<number | null>(null)
  const seen = useRef<Set<string> | null>(null)
  const [text, setText] = useState<string | null>(null)

  useEffect(() => {
    let live = true
    void (async () => {
      try {
        const client = await store.ready()
        const view = await client.call<MemoryView>('memory', { botId })
        if (!live) return
        const texts = [...view.yours.entries, ...view.bot.entries].map((e) => e.text)
        const now = new Set(texts)
        // The first read only remembers what is already there: opening the chat says nothing.
        if (seen.current === null) {
          seen.current = now
          lastRev.current = rev
          return
        }
        if (lastRev.current === rev) return
        const previous = seen.current
        const added = texts.filter((t) => !previous.has(t))
        const grew = now.size > previous.size
        seen.current = now
        lastRev.current = rev
        // Only a fact really added says so; an edit keeps the count and stays quiet.
        if (grew && added.length) setText(added[added.length - 1]!)
      } catch {
        // A host too old to answer, or offline: no hint.
      }
    })()
    return () => { live = false }
  }, [rev, store, botId])

  useEffect(() => {
    if (!text) return
    const timer = setTimeout(() => setText(null), 4200)
    return () => clearTimeout(timer)
  }, [text])

  if (!text) return null
  return (
    <div className="memory-notice" role="status" aria-live="polite">
      <Icon name="brain" size={13} color="var(--secondary)" />
      <Text size="footnote" tone="secondary" truncate>{tr('Remembered: {text}').replace('{text}', text)}</Text>
    </div>
  )
}
