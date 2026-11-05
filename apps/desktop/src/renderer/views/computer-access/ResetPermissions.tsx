import { useState } from 'react'
import type { ScreenHelperDetails } from '@shared/computer-access'
import { Button } from '../../components/Controls'
import { useTr } from '../../lib/use-language'

export function ResetPermissions({ helper }: { helper: ScreenHelperDetails }) {
  const tr = useTr()
  const [copied, setCopied] = useState(false)
  const commands = [
    `tccutil reset ScreenCapture ${helper.appBundleId}`,
    `tccutil reset ScreenCapture ${helper.bundleId}`,
    `tccutil reset Accessibility ${helper.bundleId}`,
  ].join('\n')
  return <details className="computer-access-reset">
    <summary>{tr('Reset permissions')}</summary>
    <p>{tr('If the app’s signing identity changed, turn off Remote screen in the menu bar and quit Codync. Run these commands in Terminal, then reopen Codync, enable Codync Screen, and grant access again.')}</p>
    <pre><code>{commands}</code></pre>
    <Button kind="secondary" onClick={() => {
      window.codync.app.copy(commands)
      setCopied(true)
    }}>{copied ? 'Copied' : 'Copy commands'}</Button>
  </details>
}
