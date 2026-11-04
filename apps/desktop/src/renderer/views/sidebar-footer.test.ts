import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { test } from 'node:test'
import { accountsInUse } from '../lib/account-mode.ts'
import type { CloudStatus } from '../../shared/models.ts'

const cloud = (enabled: boolean): CloudStatus => ({ enabled })

// Regression: turning this computer's cloud off must not change the number of hooks SidebarFooter
// renders. It used to call `useAccountNotice` inside `showAccount ? … : null`; when the host
// reported `cloud.enabled: false`, that hook vanished between renders and React threw #300,
// blanking the whole window (and with it Settings). The hook must stay unconditional and only
// its result may be dropped.
const source = readFileSync(join(import.meta.dirname, 'SidebarFooter.tsx'), 'utf8')

test('SidebarFooter calls useAccountNotice unconditionally', () => {
  assert.match(source, /const accountNotice = useAccountNotice\(onComputers\)/,
    'useAccountNotice must be called outside any conditional')
  assert.doesNotMatch(source, /showAccount\s*\?\s*useAccountNotice\(/,
    'a hook behind a conditional changes the hook count between renders (React #300)')
})

test('cloud going off flips the account out of use without a hook-count change', () => {
  // Unknown cloud keeps the account (no flash), then the host answers "off": the derived flag flips
  // exactly once, which is the transition that used to crash the renderer.
  assert.equal(accountsInUse(true, null), true, 'unknown cloud keeps the account')
  assert.equal(accountsInUse(true, cloud(true)), true, 'cloud on keeps the account')
  assert.equal(accountsInUse(true, cloud(false)), false, 'cloud off drops the account entry')
  assert.equal(accountsInUse(false, cloud(false)), false, 'no account build stays without one')
})
