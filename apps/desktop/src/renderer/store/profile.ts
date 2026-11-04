import type { LocalProfileState } from '@shared/ipc'
import { Observable, useModel } from '../lib/observable'

/**
 * This device's own profile, for when the Codync account is out of the picture (cloud off, C0107).
 *
 * Everything here is local: the name and the avatar were chosen on this machine, and the email is
 * whatever Google address the host recorded for a device that paired with it. Nothing is fetched
 * from the network, so the sidebar can show who this computer is with no account at all.
 */
export class LocalProfile extends Observable {
  name: string | null = null
  avatarURL: string | null = null
  email: string | null = null
  private started = false

  /** What the sidebar and the menu call this device when the user named nothing. */
  get displayName(): string {
    return this.name ?? '本机'
  }

  async start() {
    if (this.started) return
    this.started = true
    try {
      this.apply(await window.codync.profile.state())
    } catch {
      // A window opened before the main process wired the channel keeps the defaults.
    }
  }

  /** Re-reads the state, e.g. after Settings changed it. */
  async refresh() {
    try {
      this.apply(await window.codync.profile.state())
    } catch {}
  }

  async setName(name: string) {
    this.apply(await window.codync.profile.setName(name))
  }

  /** Opens the image picker; the returned state already carries the new avatar. */
  async pickAvatar() {
    this.apply(await window.codync.profile.pickAvatar())
  }

  private apply(state: LocalProfileState) {
    this.name = state.name
    this.avatarURL = state.avatarURL
    // An email the account shows instead is not this profile's business; when the cloud is on the
    // panel reads the account, not this.
    this.email = state.email
    this.changed()
  }
}

export const profile = new LocalProfile()

export function useProfile() {
  return useModel(profile)
}
