import { useState } from 'react'
import { BotAvatar } from '../../components/Avatar'
import { Button } from '../../components/ui/button'
import { IconButton } from '../../components/Controls'
import { Icon } from '../../components/Icon'
import { Text } from '../../components/Text'
import { Textarea } from '../../components/ui/textarea'
import { useTr } from '../../lib/use-language'
import { avatarColor } from '../../lib/theme'
import { useStore } from '../../store/context'
import { BotPair } from './BotPair'
import { useBotConversation } from './BotConversation'
import { Bubble, TimeSeparator } from './ChatRows'
import { MarkdownText } from './Markdown'
import './bot-chat-panel.css'

/**
 * The conversation with one peer, docked beside the main chat (C0096), laid out to the Figma frame
 * (C0100): a centred title, each message's sender named in that bot's own colour with its avatar at
 * the bubble's bottom-left corner, and a 44-tall box at the foot. It draws the bot-to-bot exchange
 * the tag bar's “N messages” card opens; the box sends straight to that peer with the app's own
 * `store.send` when the peer is a bot on this computer.
 */
export function BotChatPanel({ botId, peerId, peerName, onClose }: {
  botId: string
  peerId: string
  /** The name the peer goes by, so the title and the box read it before its history loads. */
  peerName: string
  onClose: () => void
}) {
  const tr = useTr()
  const store = useStore()
  const { rows, error, fetched } = useBotConversation(botId, peerId)
  const mine = store.bots.get(peerId)
  const sent = mine ? store.allEntries(peerId).filter((e) => e.kind === 'user' && e.data.text) : []
  const [draft, setDraft] = useState('')
  const send = () => {
    const text = draft.trim()
    if (!text || !mine) return
    store.send(text, peerId)
    setDraft('')
  }
  const name = (id: string) => store.authorName(id, id === peerId ? peerName : undefined)
  /**
   * Every sender's name takes its own bot's theme colour (C0101) — the main bot and the peer alike,
   * one rule for both. The colour is nudged toward the text colour so a dark swatch still reads on
   * the ground; a bot we don't have (a peer on another computer) uses the text colour, never a
   * fixed grey.
   */
  const nameColor = (id: string) => {
    const bot = store.bots.get(id)
    return bot ? `color-mix(in srgb, ${avatarColor(bot.avatarColor)} 60%, var(--text))` : 'var(--text)'
  }
  return (
    <aside className="bot-chat-panel" aria-label={tr('Conversation with {name}').replaceAll('{name}', () => peerName)}>
      <div className="bot-chat-panel-head">
        <div className="bot-chat-panel-title">
          <BotPair botId={botId} peer={{ id: peerId, name: peerName }} />
        </div>
        {/* A placeholder for now: no menu behind it yet. */}
        <div className="bot-chat-panel-head-actions">
          <IconButton title="More" icon="ellipsis" size={26} onClick={() => undefined} />
          <IconButton title="Close" icon="xmark" size={26} onClick={onClose} />
        </div>
      </div>
      <div className="bot-chat-panel-scroll">
        {error ? <Text as="div" size="footnote" tone="danger" className="bot-chat-panel-note">{error}</Text> : null}
        {!error && fetched && rows.length === 0 ? <Text as="div" size="footnote" tone="tertiary" className="bot-chat-panel-note">{tr('No messages yet.')}</Text> : null}
        {rows.map((row) => {
          if (row.kind === 'separator') return <TimeSeparator key={row.id} date={row.at} />
          if (row.kind === 'status') {
            const text = row.outcome.kind === 'failed' ? row.outcome.detail || tr("Didn't complete.") : tr('Waiting for {name}…').replaceAll('{name}', () => name(row.awaiting))
            return <Text key={row.id} as="div" size="footnote" tone={row.outcome.kind === 'failed' ? 'danger' : 'secondary'} className="bot-chat-panel-status">{text}</Text>
          }
          const bot = store.bots.get(row.author)
          return (
            <div key={row.id} className="panel-msg">
              <span className="panel-msg-avatar">{bot ? <BotAvatar bot={bot} size={24} animated={false} /> : null}</span>
              <div className="panel-msg-content">
                <div className="panel-msg-name">
                  <Text size="subheadline" weight="medium" style={{ color: nameColor(row.author) }}>{name(row.author)}</Text>
                </div>
                <Bubble className="bubble agent selectable" items={() => [{ title: 'Copy', icon: 'square.on.square', action: () => window.codync.app.copy(row.text) }]}>
                  <MarkdownText text={row.text} />
                </Bubble>
              </div>
            </div>
          )
        })}
        {mine && sent.length ? (
          <div className="bot-chat-panel-mine">
            <Text as="div" size="footnote" tone="tertiary" className="bot-chat-panel-mine-title">
              {tr('You to {name}').replaceAll('{name}', () => peerName)}
            </Text>
            {sent.map((e) => (
              <div key={e.id} className="panel-msg">
                <span className="panel-msg-avatar" />
                <div className="panel-msg-content">
                  <div className="bubble agent selectable"><MarkdownText text={e.data.text ?? ''} /></div>
                </div>
              </div>
            ))}
          </div>
        ) : null}
      </div>
      {mine ? (
        <div className="bot-chat-panel-composer">
          <div className="bot-chat-panel-box">
            <Textarea
              rows={1}
              value={draft}
              placeholder={tr('Message {name}').replaceAll('{name}', () => peerName)}
              aria-label={tr('Message {name}').replaceAll('{name}', () => peerName)}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
                  e.preventDefault()
                  send()
                }
              }}
            />
            <Button size="icon" className="press bot-chat-panel-send" aria-label={tr('Send')} title={tr('Send')} disabled={!draft.trim()} onClick={send}>
              <Icon name="arrow.up" size={13} weight="bold" />
            </Button>
          </div>
        </div>
      ) : (
        <div className="bot-chat-panel-composer">
          <Text as="div" size="footnote" tone="tertiary" className="bot-chat-panel-hint">
            {tr('Not on this computer: ask {name}’s own chat to reply.').replaceAll('{name}', () => peerName)}
          </Text>
        </div>
      )}
    </aside>
  )
}
