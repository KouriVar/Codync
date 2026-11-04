import type { CloudStatus } from '@shared/models'

/**
 * Whether the account is in play on this computer: the build has accounts *and* this computer's
 * host keeps its cloud on. A fork/self-hosted setup runs the host with `CODYNC_CLOUD=off`
 * (C0107): the account cannot reach anyone then, so the app stays out of its way — no welcome
 * blocking the window, no account entries in the sidebar and Settings. Nothing is removed: with
 * the cloud back on, everything returns.
 *
 * `cloud` is null until this computer's host has answered. Unknown is not "off": dropping the
 * account on a launch that turns out to have it would flash the main window behind the welcome
 * and could show account entries late, so an unknown cloud keeps whatever the build says.
 */
export function accountsInUse(configured: boolean, cloud: CloudStatus | null | undefined) {
  return configured && cloud?.enabled !== false
}

/** Whether the account is configured but switched off by this computer's host (the hidden state). */
export function accountHidden(configured: boolean, cloud: CloudStatus | null | undefined) {
  return configured && !accountsInUse(configured, cloud)
}
