import assert from 'node:assert/strict'
import { test } from 'node:test'
import { systemSettingsURL } from './open-settings.ts'

test('a settings pane URL is passed through', () => {
  const url = 'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture'
  assert.equal(systemSettingsURL(url), url)
})

test('a missing or non-settings target is dropped instead of throwing', () => {
  // The renderer's openSettings() can send no argument at all (a permission the URL map lacks);
  // that used to crash the main process on `undefined.startsWith`.
  assert.equal(systemSettingsURL(undefined), null)
  assert.equal(systemSettingsURL(null), null)
  assert.equal(systemSettingsURL(''), null)
  assert.equal(systemSettingsURL('https://example.com'), null)
  assert.equal(systemSettingsURL(42), null)
  assert.equal(systemSettingsURL({ startsWith: () => true }), null)
})
