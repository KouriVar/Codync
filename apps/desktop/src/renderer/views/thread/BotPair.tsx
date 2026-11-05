import { BotAvatar } from '../../components/Avatar'
import { Icon } from '../../components/Icon'
import { HStack } from '../../components/Stack'
import { Text } from '../../components/Text'
import { useStore } from '../../store/context'
import { useTr } from '../../lib/use-language'
import { fill } from '../../lib/fill.ts'

/** A conversation's peer, with the name it goes by when it is on another computer. */
export interface Peer {
  id: string
  name?: string
}

/** The pair a conversation is between, for its header: the chat's own bot, then its peer. */
export function BotPair({ botId, peer }: { botId: string; peer: Peer }) {
  const tr = useTr()
  const store = useStore()
  const name = (id: string) => store.authorName(id, id === peer.id ? peer.name : undefined)
  const label = (id: string) => (
    <HStack as="span" gap={6} shrink>
      {store.bots.get(id) ? <BotAvatar bot={store.bots.get(id)!} size={20} animated={false} /> : null}
      <Text truncate>{name(id)}</Text>
    </HStack>
  )
  return (
    <HStack as="span" gap={8} aria-label={fill(tr('{name} and {other}'), { name: name(botId), other: name(peer.id) })}>
      {label(botId)}
      <Icon name="arrow.left.arrow.right" size={11} color="var(--tertiary)" />
      {label(peer.id)}
    </HStack>
  )
}
