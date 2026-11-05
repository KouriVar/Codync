import { isOutgoing, type BotExchange } from './bot-exchange'

/**
 * What the card says in its top-right corner. `failed` is the failure the transcript already
 * flags (C0094), not one of the three states the card was designed for.
 */
export type DelegateStatus = 'working' | 'replied' | 'needs-decision' | 'failed'

/** The peer has said something in this exchange: it replied to ours, or its message started it. */
const answered = (x: BotExchange) => (isOutgoing(x) ? Boolean(x.message.reply) : true)

/**
 * The run's state from what the transcript already carries: a failed exchange stays the failure
 * that was already shown, an answered exchange is `replied`, and an open one is `working` — or
 * `needs-decision` when the peer's own bot status says it is waiting on the user.
 */
export function delegateStatus(xs: BotExchange[], peerNeedsInput: boolean): DelegateStatus {
  if (xs.some((x) => x.outcome.kind === 'failed')) return 'failed'
  const latest = xs[xs.length - 1]!
  if (latest.outcome.kind === 'pending' && !answered(latest)) return peerNeedsInput ? 'needs-decision' : 'working'
  return 'replied'
}

/** The peer's newest message in the run, for the card's second line: its reply, or its own message. */
export function peerLatestMessage(xs: BotExchange[]): string | undefined {
  for (let i = xs.length - 1; i >= 0; i--) {
    const x = xs[i]!
    if (!isOutgoing(x)) return x.message.text
    if (x.message.reply) return x.message.reply
  }
  return undefined
}
