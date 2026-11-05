import type { ScreenHelperDetails } from '@shared/computer-access'
import { Button } from '../../components/Controls'
import { Icon } from '../../components/Icon'
import { useTr } from '../../lib/use-language'

export function HelperPermissionCard({ helper, permission }: { helper: ScreenHelperDetails; permission: 'capture' | 'input' }) {
  const tr = useTr()
  const instructions = tr(permission === 'capture'
    ? 'Drag into Screen & System Audio Recording'
    : 'Drag into Accessibility')
  return <div className="computer-access-helper">
    {helper.icon ? <div className="computer-access-helper-card" draggable onDragStart={(event) => {
      event.preventDefault()
      window.codync.app.dragScreenHelper()
    }}>
      <img src={helper.icon} width={32} height={32} alt="" draggable={false} />
      <div><strong>{helper.name}</strong><p>{instructions}</p></div>
    </div> : null}
    <Button kind="secondary" onClick={() => window.codync.app.revealScreenHelper()}>
      {tr('Show in Finder')} <Icon name="arrow.up.right.square" size={10} />
    </Button>
  </div>
}
