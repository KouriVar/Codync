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


/**
 * A run of bot-to-bot messages with one peer, as a card in the message flow (C0094). The transcript
 * no longer shows it (C0096); the pair and the state it draws stay for the tag bar and the panel.
 */
export function BotMessageRow({ exchanges, open }: { exchanges: BotExchange[]; open: (peerId: string) => void }) {
  return <DelegateCard exchanges={exchanges} open={open} />
}

/**
 * The history between a bot and one peer — the live chat merged with what the host returns — as the
 * rows to draw and the peer they are with. The plain sheet and the Mac's docked panel both read it.
 */
export function useBotConversation(botId: string, peerId: string) {
  const store = useStore()
  // null while the host's history loads.
  const { fetched, error } = useFetched(() => store.botConversation(botId, peerId), [store, botId, peerId])
  const exchanges = botConversation(fetched ?? [], store.allEntries(botId), peerId)
  const rows = buildBotConversation(exchanges)
  const peer: Peer = { id: peerId, name: peerNameIn(exchanges) }
  return { rows, error, fetched, peer }
}

/** The conversation's rows, scrolled to the newest; a note while it loads or is empty. */
export function BotConversationScroll({ rows, peer, error, fetched }: {
  rows: BotConversationRow[]
  peer: Peer
  error: string | null
  fetched: unknown
}) {
  const tr = useTr()
  const scroller = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const el = scroller.current
    if (el) el.scrollTop = el.scrollHeight
  }, [rows.length, rows[rows.length - 1]?.id])
  return (
    <div className="bot-conversation-scroll" ref={scroller}>
      <div className="bot-conversation-rows">
        {error ? <Text as="div" size="footnote" tone="danger" className="bot-conversation-note">{error}</Text> : null}
        {!error && fetched && rows.length === 0 ? <Text as="div" size="footnote" tone="tertiary" className="bot-conversation-note">{tr(`No messages yet.`)}</Text> : null}
        {rows.map((row) => <ConversationRow key={row.id} row={row} peer={peer} />)}
      </div>
    </div>
  )
}

/** Read-only history between a bot and one peer: the live chat merged with what the host returns. */
export function BotConversationView({ botId, peerId }: { botId: string; peerId: string }) {
  const { rows, error, fetched, peer } = useBotConversation(botId, peerId)
  return (
    <div className="bot-conversation">
      <ModalHeader title={<BotPair botId={botId} peer={peer} />} />
      <BotConversationScroll rows={rows} peer={peer} error={error} fetched={fetched} />
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
