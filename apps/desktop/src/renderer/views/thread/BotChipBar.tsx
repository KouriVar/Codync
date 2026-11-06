import { isWorking, needsInput } from '@shared/models'
import { BotAvatar } from '../../components/Avatar'
import { Text } from '../../components/Text'
import { useTr } from '../../lib/use-language'
import { useStore } from '../../store/context'
import { peerNameIn } from './bot-exchange'
import { delegatedPeers, type Mention } from './bot-chips'
import { DELEGATE_STATUS_DOTS, DELEGATE_STATUS_LABELS, delegateStatus } from './delegate-card'
import './bot-chips.css'

/**
 * The bots this chat has worked with (C0095), over its message box: each is an avatar with a status
 * dot (red broke · orange running · blue awaiting you · green done), a count card above opens the
 * docked conversation (C0096), and the row above lists whoever is running right now. Tapping a tag
 * addresses that bot (`@name`); tapping it again lets go.
 */
export function BotChipBar({ botId, mention, pick, openChat }: {
  botId: string
  mention: Mention | null
  pick: (mention: Mention | null) => void
  /** The count card above a tag: opens the peer's conversation in the right-hand panel. */
  openChat: (peerId: string, name: string) => void
}) {
  const tr = useTr()
  const store = useStore()
  const peers = delegatedPeers(store.allEntries(botId)).map(({ peerId, exchanges }) => {
    const bot = store.bots.get(peerId)
    const name = store.authorName(peerId, peerNameIn(exchanges))
    return { peerId, exchanges, bot, name, state: delegateStatus(exchanges, bot ? needsInput(bot) : false) }
  })
  if (!peers.length) return null
  const running = peers.filter((p) => p.bot && isWorking(p.bot))
  return (
    <div className="bot-chip-bar-wrap">
      {running.length ? (
        <div className="bot-chip-running" role="list" aria-label={tr('Bots working now')}>
          {running.map(({ peerId, bot, name }) => (
            <div key={peerId} className="bot-chip-running-item" role="listitem">
              {bot ? <BotAvatar bot={bot} size={16} animated={false} /> : null}
              <Text size="footnote" weight="medium" truncate>{name}</Text>
              <Text size="footnote" tone="secondary" truncate>{tr(bot?.activity || 'Working…')}</Text>
            </div>
          ))}
        </div>
      ) : null}
      <div className="bot-chip-bar" role="toolbar" aria-label="Bots in this conversation">
        {peers.map(({ peerId, bot, name, state, exchanges }) => {
          const chosen = mention?.id === peerId
          const dot = DELEGATE_STATUS_DOTS[state]
          const label = `@${name} · ${tr(DELEGATE_STATUS_LABELS[state])}`
          // C0125: ONE card that grows from a 30-tall chip into a 62-tall card (two variants); the
          // "N messages · name" line reveals on top, avatar+name stays at the bottom.
          const summary = `${tr('{count} messages').replaceAll('{count}', () => String(exchanges.length))} ${name}`
          return (
            <div key={peerId} className="bot-chip-item">
              <div className={`bot-chip-card${exchanges.length > 0 ? ' has-count' : ''}`}>
                {exchanges.length > 0 ? (
                  <button
                    type="button"
                    className="bot-chip-count"
                    title={summary}
                    onClick={() => openChat(peerId, name)}
                  >
                    {summary}
                  </button>
                ) : null}
                <button
                  type="button"
                  className={chosen ? 'bot-chip chosen' : 'bot-chip'}
                  aria-pressed={chosen}
                  title={label}
                  aria-label={label}
                  onClick={() => pick(chosen ? null : { id: peerId, name })}
                >
                  <span className="bot-chip-avatar">
                    {bot ? (
                      <>
                        <BotAvatar bot={bot} size={20} animated={false} />
                        <span className={`bot-chip-status ${dot}`} aria-hidden="true" />
                      </>
                    ) : null}
                  </span>
                  <Text size="body" weight={chosen ? 'semibold' : 'medium'} truncate>{name}</Text>
                </button>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
