import type { Entry } from '@shared/models'
import { botExchange, peerOf, type BotExchange } from './bot-exchange'

/** A bot the message box can address, by the name it goes by: `@name` goes out with the message. */
export interface Mention {
  id: string
  name: string
}

/** One bot this chat has delegated to or heard back from, with everything exchanged with it. */
export interface DelegatedPeer {
  peerId: string
  /** Oldest first, so the last one is how the exchange stands now. */
  exchanges: BotExchange[]
}

const lastAt = (xs: BotExchange[]) => xs.reduce((at, x) => Math.max(at, x.createdAt), 0)

/**
 * The bots a chat has worked with: every peer in a bot-to-bot notice (delegated to, or one that
 * wrote to this chat), most recently active first. Empty when it never delegated to anyone.
 */
export function delegatedPeers(entries: Entry[]): DelegatedPeer[] {
  const byPeer = new Map<string, BotExchange[]>()
  for (const entry of entries) {
    const x = botExchange(entry)
    if (!x) continue
    const peer = peerOf(x)
    const run = byPeer.get(peer)
    if (run) run.push(x)
    else byPeer.set(peer, [x])
  }
  return [...byPeer]
    .map(([peerId, exchanges]) => ({ peerId, exchanges: exchanges.sort((a, b) => a.seq - b.seq) }))
    .sort((a, b) => lastAt(b.exchanges) - lastAt(a.exchanges))
}
