import { useContext, useEffect, useState } from 'react'
import { Icon } from '../../components/Icon'
import { AppContext } from '../../store/context'
import './citation.css'

/** Where a clicked citation wants to go: the bot whose chat holds it, and the message. */
export interface CiteTarget {
  botId: string
  entryId: string
  /** Bumped on every request so clicking the same one twice still scrolls. */
  n: number
}

let seq = 0
const listeners = new Set<(target: CiteTarget) => void>()

/** Ask the open chat to scroll to a cited message (C0104). */
export function requestCiteJump(botId: string, entryId: string) {
  const target: CiteTarget = { botId, entryId, n: ++seq }
  for (const listener of listeners) listener(target)
}

function subscribeCite(fn: (target: CiteTarget) => void) {
  listeners.add(fn)
  return () => {
    listeners.delete(fn)
  }
}

/** The pending jump, when it is for this bot. */
export function useCiteJump(botId: string): CiteTarget | null {
  const [target, setTarget] = useState<CiteTarget | null>(null)
  useEffect(() => subscribeCite((next) => { if (next.botId === botId) setTarget(next) }), [botId])
  return target
}

/**
 * A citation marker the bot wrote as `[[cite:<botId>/<entryId>]]`, drawn as a small chip. Clicking it
 * opens that bot's conversation and scrolls to the message it quotes (loading earlier pages if it
 * hasn't been paged in yet).
 */
export function CiteChip({ botId, entryId }: { botId: string; entryId: string }) {
  const app = useContext(AppContext)
  const name = app?.roster.find((item) => item.bot.id === botId)?.bot.name
  return (
    <button
      type="button"
      className="cite-chip"
      title={name ? `引用 · ${name}` : '引用'}
      onClick={(e) => {
        e.preventDefault()
        e.stopPropagation()
        const item = app?.roster.find((i) => i.bot.id === botId)
        if (app && item) app.select(item.ref)
        requestCiteJump(botId, entryId)
      }}
    >
      <Icon name="text.bubble" size={10} color="var(--secondary)" />
      {name ?? '引用'}
    </button>
  )
}
