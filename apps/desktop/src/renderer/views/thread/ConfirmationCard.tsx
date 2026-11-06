import { Button } from '../../components/Controls'
import { HStack, VStack } from '../../components/Stack'
import { Text } from '../../components/Text'
import { confirmationCardCopy as copy } from './confirmation-card-copy'
import './permission-card.css'

/** The presentation shell. The confirmation flow will supply its action and reason in phase three. */
export function ConfirmationCard({ action, reason }: { action?: string; reason?: string }) {
  return (
    <VStack gap={10} className="permission-card">
      <Text as="h2" size="headline" tone="text">{copy.title}</Text>
      <dl>
        <dt>{copy.action}</dt>
        <dd>{action}</dd>
        <dt>{copy.reason}</dt>
        <dd>{reason}</dd>
      </dl>
      <HStack gap={8}>
        <Button disabled>{copy.approve}</Button>
        <Button kind="secondary" disabled>{copy.reject}</Button>
      </HStack>
    </VStack>
  )
}
