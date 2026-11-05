import { needsInput } from '@shared/models'
import { BotAvatar } from '../../components/Avatar'
import { Text } from '../../components/Text'
import { useTr } from '../../lib/use-language'
import { useStore } from '../../store/context'
import { peerNameIn } from './bot-exchange'
import { delegatedPeers, type Mention } from './bot-chips'
import { DELEGATE_STATUS_LABELS, delegateStatus } from './delegate-card'
import './bot-chips.css'

/**
 * The bots this chat has worked with, in one row over its message box: tap one to address it
 * (`@name`), tap it again to let go. Not shown until the chat has delegated to or heard from one.
 */
export function BotChipBar({ botId, mention, pick }: { botId: string; mention: Mention | null; pick: (mention: Mention | null) => void }) {
  const tr = useTr()
  const store = useStore()
  const peers = delegatedPeers(store.allEntries(botId))
  if (!peers.length) return null
  return (
    <div className="bot-chip-bar" role="toolbar" aria-label="Bots in this conversation">
      {peers.map(({ peerId, exchanges }) => {
        const bot = store.bots.get(peerId)
        const name = store.authorName(peerId, peerNameIn(exchanges))
        const state = delegateStatus(exchanges, bot ? needsInput(bot) : false)
        const chosen = mention?.id === peerId
        const label = `@${name} · ${tr(DELEGATE_STATUS_LABELS[state])}`
        return (
          <button
            key={peerId}
            className={chosen ? 'press bot-chip chosen' : 'press bot-chip'}
            aria-pressed={chosen}
            title={label}
            aria-label={label}
            onClick={() => pick(chosen ? null : { id: peerId, name })}
          >
            {bot ? <BotAvatar bot={bot} size={16} animated={false} /> : null}
            <Text size="footnote" weight={chosen ? 'semibold' : 'regular'} truncate>{name}</Text>
            <span className={`bot-chip-status ${state}`} aria-hidden="true" />
          </button>
        )
      })}
    </div>
  )
}
