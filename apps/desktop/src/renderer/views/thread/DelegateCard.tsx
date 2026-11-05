import { needsInput } from '@shared/models'
import { HStack } from '../../components/Stack'
import { Text, type Tone } from '../../components/Text'
import { messagePreviewLines } from '../../lib/message-preview'
import { useTr } from '../../lib/use-language'
import { useStore } from '../../store/context'
import { groupSummary, verbOf, type BotExchange } from './bot-exchange'
import { BotPair } from './BotPair'
import { delegateStatus, peerLatestMessage, type DelegateStatus } from './delegate-card'
import './delegate-card.css'

/** The card's three states, plus the failure the transcript already reports (C0094). */
const LABELS: Record<DelegateStatus, string> = {
  working: 'Working on it',
  replied: 'Replied',
  'needs-decision': 'Needs your decision',
  failed: "Didn't complete",
}

const TONES: Record<DelegateStatus, Tone> = {
  working: 'secondary',
  replied: 'tertiary',
  'needs-decision': 'attention',
  failed: 'danger',
}

/**
 * One card in place of a run of bot-to-bot messages with one peer: the pair (the conversation
 * sheet's own header), the peer's newest line, and how it stands. Tapping opens that conversation.
 */
export function DelegateCard({ exchanges, open }: { exchanges: BotExchange[]; open: (peerId: string) => void }) {
  const tr = useTr()
  const store = useStore()
  const { peerId, peerName, count } = groupSummary(exchanges)
  const name = store.authorName(peerId, peerName)
  const peer = store.bots.get(peerId)
  const state = delegateStatus(exchanges, peer ? needsInput(peer) : false)
  const latest = peerLatestMessage(exchanges)
  const preview = latest ? messagePreviewLines(latest, 2) : ''
  const lead = count > 1 ? `${count} messages with` : verbOf(exchanges[0]!)
  return (
    <button
      className="press delegate-card"
      onClick={() => open(peerId)}
      title="Open conversation"
      aria-label={`${lead} ${name}, ${tr(LABELS[state])}`}
    >
      <HStack justify="space-between" gap={8}>
        <HStack grow>
          <BotPair botId={exchanges[0]!.chat} peer={{ id: peerId, name: peerName }} />
        </HStack>
        <Text size="caption" weight="medium" tone={TONES[state]} className="delegate-card-status">{tr(LABELS[state])}</Text>
      </HStack>
      {preview ? <Text as="div" size="footnote" tone="secondary" lines={2} className="delegate-card-preview">{preview}</Text> : null}
    </button>
  )
}
