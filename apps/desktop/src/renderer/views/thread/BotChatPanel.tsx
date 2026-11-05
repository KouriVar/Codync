import { useState } from 'react'
import { IconButton } from '../../components/Controls'
import { Icon } from '../../components/Icon'
import { HStack } from '../../components/Stack'
import { Text } from '../../components/Text'
import { useTr } from '../../lib/use-language'
import { useStore } from '../../store/context'
import { BotPair } from './BotPair'
import { BotConversationScroll, useBotConversation } from './BotConversation'
import { MarkdownText } from './Markdown'
import './bot-chat-panel.css'

/**
 * The conversation with one peer, docked beside the main chat (C0096): the bot-to-bot exchange the
 * tag bar's “N messages” card opens, drawn as rows rather than as a sheet, all left-aligned. Its own
 * box below sends straight to that peer — the same `store.send` the rest of the app uses — when the
 * peer is a bot on this computer; a peer on another computer has nothing here to carry a message.
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
  const { rows, error, fetched, peer } = useBotConversation(botId, peerId)
  const mine = store.bots.get(peerId)
  const sent = mine ? store.allEntries(peerId).filter((e) => e.kind === 'user' && e.data.text) : []
  const [draft, setDraft] = useState('')
  const send = () => {
    const text = draft.trim()
    if (!text || !mine) return
    store.send(text, peerId)
    setDraft('')
  }
  return (
    <aside className="bot-chat-panel" aria-label={tr('Conversation with {name}').replaceAll('{name}', () => peerName)}>
      <div className="bot-chat-panel-head">
        <HStack gap={8} grow>
          <BotPair botId={botId} peer={{ ...peer, name: peer.name ?? peerName }} />
        </HStack>
        {/* A placeholder for now: no menu behind it yet. */}
        <IconButton title="More" icon="ellipsis" onClick={() => undefined} />
        <IconButton title="Close" icon="xmark" onClick={onClose} />
      </div>
      <div className="bot-chat-panel-scroll">
        <BotConversationScroll rows={rows} peer={peer} error={error} fetched={fetched} />
        {mine && sent.length ? (
          <div className="bot-chat-panel-mine">
            <Text as="div" size="footnote" tone="tertiary" className="bot-chat-panel-mine-title">
              {tr('You to {name}').replaceAll('{name}', () => peerName)}
            </Text>
            {sent.map((e) => (
              <div key={e.id} className="message agent">
                <div className="message-body">
                  <div className="bubble agent selectable"><MarkdownText text={e.data.text ?? ''} /></div>
                </div>
              </div>
            ))}
          </div>
        ) : null}
      </div>
      {mine ? (
        <div className="bot-chat-panel-composer">
          <HStack gap={6} className="bot-chat-panel-box">
            <textarea
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
            <button className="press bot-chat-panel-send" aria-label={tr('Send')} title={tr('Send')} disabled={!draft.trim()} onClick={send}>
              <Icon name="arrow.up" size={13} weight="bold" />
            </button>
          </HStack>
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
