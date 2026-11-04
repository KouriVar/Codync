import assert from 'node:assert/strict'
import { test } from 'node:test'
import { accountHidden, accountsInUse } from './account-mode.ts'
import type { CloudStatus } from '../../shared/models.ts'

const cloud = (enabled: boolean): CloudStatus => ({ enabled })

test('with this computer cloud on, the account stays in use', () => {
  assert.equal(accountsInUse(true, cloud(true)), true)
  assert.equal(accountHidden(true, cloud(true)), false)
})

test('with this computer cloud off, the account is hidden but still configured', () => {
  assert.equal(accountsInUse(true, cloud(false)), false, 'no welcome, no account entries')
  assert.equal(accountHidden(true, cloud(false)), true)
})

test('an unknown cloud keeps what the build says', () => {
  // The host has not answered yet: a configured build keeps its account rather than flashing the
  // window and then showing account entries late.
  assert.equal(accountsInUse(true, null), true)
  assert.equal(accountsInUse(true, undefined), true)
  assert.equal(accountHidden(true, null), false)
})

test('a build without accounts never has them in use', () => {
  assert.equal(accountsInUse(false, cloud(true)), false)
  assert.equal(accountsInUse(false, cloud(false)), false)
  assert.equal(accountHidden(false, cloud(true)), false, 'nothing is hidden that was never shown')
  assert.equal(accountHidden(false, null), false)
})
