import { execFile } from 'node:child_process'
import { existsSync, statSync } from 'node:fs'
import { join } from 'node:path'
import { promisify } from 'node:util'
import { app, ipcMain, nativeImage, shell, type NativeImage } from 'electron'
import { prefs } from './host-controller'
import { identity } from './environment'
import { shouldSyncScreenAgent } from '../shared/computer-access'

// Codync Screen (capture + input for Remote screen): on macOS a launchd agent inside the app
// bundle (apps/screen-macos, registered through SMAppService). It checks the macOS grants it
// needs, including when macOS attributes screen recording to the enclosing Codync app.

const isMac = process.platform === 'darwin'
const previousService = `${identity.screenLabel}.plist`
const personalService = `${identity.screenLabel}.personal.plist`
const serviceName = isMac && app.isPackaged &&
  existsSync(join(process.resourcesPath, '..', 'Library/LaunchAgents', personalService))
  ? personalService : previousService
const screenBundlePath = join(process.resourcesPath, '..', 'Library/LoginItems', `${identity.screenName}.app`)
const screenExecutablePath = join(screenBundlePath, 'Contents/MacOS', identity.screenName)
let helperIcon: NativeImage | undefined

function hasBundledHelper() {
  return isMac && app.isPackaged && existsSync(screenExecutablePath)
}

async function helperDetails() {
  if (!hasBundledHelper()) return null
  const name = await promisify(execFile)('/usr/bin/plutil', ['-extract', 'CFBundleDisplayName', 'raw', join(screenBundlePath, 'Contents/Info.plist')])
    .then(({ stdout }) => stdout.trim()).catch(() => `${identity.name} Screen`)
  // Xcode exports this from the helper's compiled AppIcon.icns before signing it.
  const icon = nativeImage.createFromPath(join(screenBundlePath, 'Contents/Resources/PermissionIcon.png'))
  helperIcon = icon.isEmpty() ? undefined : icon.resize({ width: 32, height: 32 })
  return { name, bundleId: identity.screenLabel, appBundleId: identity.appId, icon: helperIcon ? icon.toDataURL() : null }
}

/** Identifies the helper binary even if an app replacement preserves its modification date. */
function helperStamp() {
  try {
    const { dev, ino, mtimeMs } = statSync(screenExecutablePath)
    return `${screenExecutablePath}@${dev}:${ino}:${mtimeMs}`
  } catch {
    return `${screenExecutablePath}@0`
  }
}

function status(service = serviceName): string {
  if (!isMac || !app.isPackaged) return 'not-registered'
  return app.getLoginItemSettings({ type: 'agentService', serviceName: service }).status ?? 'not-registered'
}

function previousServiceRegistered() {
  if (serviceName === previousService) return false
  const previousStatus = status(previousService)
  return previousStatus === 'enabled' || previousStatus === 'requires-approval'
}

/** Registers (or removes) the agent; returns whether macOS wants the user to allow it. */
export function setScreenAgent(on: boolean): { needsApproval: boolean } {
  if (!isMac || !app.isPackaged) return { needsApproval: false }
  const previousRegistered = previousServiceRegistered()
  if (on && previousRegistered) {
    throw new Error('Turn off Remote screen in the menu bar, then turn it back on to switch to the new background service.')
  }
  // Registering an enabled agent is a no-op, so a helper launchd gave up on would never start again.
  if (on && status() === 'enabled') app.setLoginItemSettings({ type: 'agentService', serviceName, openAtLogin: false })
  app.setLoginItemSettings({ type: 'agentService', serviceName, openAtLogin: on })
  if (!on && previousRegistered) {
    app.setLoginItemSettings({ type: 'agentService', serviceName: previousService, openAtLogin: false })
  }
  prefs.set('screenHelperStamp', on ? helperStamp() : null)
  prefs.set('screenHelperResumeAfterUpdate', false)
  return { needsApproval: status() === 'requires-approval' }
}

/**
 * Keeps Codync Screen registered while the host has Remote screen on, and registers it again
 * when this app ships a different helper binary (launchd keeps running the old one).
 */
export function syncScreenAgent(enabled: boolean): { needsApproval: boolean } {
  if (!isMac || !app.isPackaged || !enabled) return { needsApproval: false }
  // A first registration belongs to explicit setup, never application startup.
  const current = status()
  if (!shouldSyncScreenAgent(enabled, current, prefs.get('screenHelperResumeAfterUpdate') === true)) {
    return { needsApproval: current === 'requires-approval' }
  }
  const stale = prefs.get('screenHelperStamp') !== helperStamp()
  if (!stale && current === 'enabled') return { needsApproval: false }
  return setScreenAgent(true)
}

/** Before the app is replaced: the old helper stops along with its job. */
export function unregisterScreenAgent() {
  if (!isMac || !app.isPackaged || status() !== 'enabled') return
  prefs.set('screenHelperResumeAfterUpdate', true)
  app.setLoginItemSettings({ type: 'agentService', serviceName, openAtLogin: false })
  prefs.set('screenHelperStamp', null)
}

export function registerScreenIPC() {
  ipcMain.handle('screen:state', () => {
    const agentStatus = status()
    return {
      available: !isMac || hasBundledHelper(),
      needsApproval: agentStatus === 'requires-approval',
      registered: agentStatus === 'enabled',
    }
  })
  ipcMain.handle('screen:helperDetails', helperDetails)
  ipcMain.on('screen:revealHelper', () => {
    if (hasBundledHelper()) shell.showItemInFolder(screenBundlePath)
  })
  ipcMain.on('screen:dragHelper', ({ sender }) => {
    if (hasBundledHelper() && helperIcon) sender.startDrag({ file: screenBundlePath, icon: helperIcon })
  })
  ipcMain.handle('screen:setAgent', (_e, on: boolean) => setScreenAgent(on))
  ipcMain.handle('screen:syncAgent', (_e, enabled: boolean) => syncScreenAgent(enabled))
}
