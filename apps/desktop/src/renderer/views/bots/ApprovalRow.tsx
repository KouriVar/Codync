import { approvals, withApproval, type ModeCatalog } from '@shared/approvals'
import type { BotDraft } from '@shared/models'
import { ValueRow } from '../../components/Controls'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../../components/ui/select'
import { useTr } from '../../lib/use-language'

/** Permissions: the modes the bot's agent offers (its model list), its Auto mode first, then approving everything. */
export function ApprovalRow({ draft, catalog, onChange }: {
  draft: BotDraft
  catalog: ModeCatalog | null
  onChange: (update: (d: BotDraft) => BotDraft) => void
}) {
  const tr = useTr()
  const { choices, selected } = approvals(draft, catalog)
  const detail = [selected.note, tr(selected.detail)].filter(Boolean).join(' ')
  return (
    <ValueRow label="Permissions" detail={detail}>
      <Select value={selected.id} onValueChange={(id) => onChange((d) => withApproval(d, id))}>
        <SelectTrigger className="w-40"><SelectValue /></SelectTrigger>
        <SelectContent>
          {choices.map((c) => <SelectItem key={c.id} value={c.id}>{tr(c.label)}</SelectItem>)}
        </SelectContent>
      </Select>
    </ValueRow>
  )
}
