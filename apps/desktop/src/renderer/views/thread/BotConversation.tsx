import { useEffect, useRef } from 'react'
import { ModalHeader } from '../../components/Overlay'
import { VStack } from '../../components/Stack'
import { Text } from '../../components/Text'
import { useStore } from '../../store/context'
import { botConversation, buildBotConversation, peerNameIn, type BotConversationRow, type BotExchange } from './bot-exchange'
import { BotPair, type Peer } from './BotPair'
import { DelegateCard } from './DelegateCard'
import { AuthorLabel, Bubble, TimeSeparator } from './ChatRows'
import { MarkdownText } from './Markdown'
import './bot-conversation.css'
import { useFetched } from '../../lib/use-fetched'
import { useTr } from '../../lib/use-language'


/** A run of bot-to-bot messages with one peer: the delegation card in the message flow. Opens the conversation. */
export function BotMessageRow({ exchanges, open }: { exchanges: BotExchange[]; open: (peerId: string) => void }) {
  return <DelegateCard exchanges={exchanges} open={open} />
}

/** Read-only history between a bot and one peer: the live chat merged with what the host returns. */
export function BotConversationView({ botId, peerId }: { botId: string; peerId: string }) {
  const tr = useTr()
  const store = useStore()
  // null while the host's history loads.
  const { fetched, error } = useFetched(() => store.botConversation(botId, peerId), [store, botId, peerId])
  const scroller = useRef<HTMLDivElement>(null)
  const exchanges = botConversation(fetched ?? [], store.allEntries(botId), peerId)
  const rows = buildBotConversation(exchanges)
  const peer = { id: peerId, name: peerNameIn(exchanges) }

  useEffect(() => {
    const el = scroller.current
    if (el) el.scrollTop = el.scrollHeight
  }, [rows.length, rows[rows.length - 1]?.id])

  return (
    <div className="bot-conversation">
      <ModalHeader title={<BotPair botId={botId} peer={peer} />} />
      <div className="bot-conversation-scroll" ref={scroller}>
        <div className="bot-conversation-rows">
          {error ? <Text as="div" size="footnote" tone="danger" className="bot-conversation-note">{error}</Text> : null}
          {!error && fetched && rows.length === 0 ? <Text as="div" size="footnote" tone="tertiary" className="bot-conversation-note">{tr(`No messages yet.`)}</Text> : null}
          {rows.map((row) => <ConversationRow key={row.id} row={row} peer={peer} />)}
        </div>
      </div>
    </div>
  )
}

function ConversationRow({ row, peer }: { row: BotConversationRow; peer: Peer }) {
  const tr = useTr()
  const store = useStore()
  const name = (id: string) => store.authorName(id, id === peer.id ? peer.name : undefined)
  switch (row.kind) {
    case 'separator':
      return <TimeSeparator date={row.at} />
    case 'message':
      return (
        <VStack align="flex-start" gap={4} className={row.showsAuthor ? 'chat-row group-start' : 'chat-row'}>
          {row.showsAuthor ? <AuthorLabel botId={row.author} name={name(row.author)} /> : null}
          <div className="message agent">
            <div className="message-body">
              <Bubble className="bubble agent selectable" items={() => [{ title: 'Copy', icon: 'square.on.square', action: () => window.codync.app.copy(row.text) }]}>
                <MarkdownText text={row.text} />
              </Bubble>
            </div>
          </div>
        </VStack>
      )
    case 'status': {
      const failed = row.outcome.kind === 'failed'
      const text = row.outcome.kind === 'failed' ? row.outcome.detail || tr("Didn't complete.") : tr('Waiting for {name}…').replaceAll('{name}', () => name(row.awaiting))
      return <Text as="div" size="footnote" tone={failed ? 'danger' : 'secondary'} className="selectable bot-conversation-status">{text}</Text>
    }
  }
}
