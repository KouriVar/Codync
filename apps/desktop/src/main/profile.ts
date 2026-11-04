import { app, dialog, ipcMain, type BrowserWindow } from 'electron'
import { copyFileSync, mkdirSync, readFileSync, readdirSync, statSync, unlinkSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { extname, join } from 'node:path'
import type { LocalProfileState } from '../shared/ipc'
import { prefs } from './host-controller'

/**
 * The profile this device shows when the Codync account is out of the picture (cloud off, C0107):
 * a name the user typed and an image they picked. Both stay on this machine — the name and the
 * file's path in host-prefs.json, the file itself beside it in the app's data folder. Nothing is
 * fetched from the network, and no Google name or picture is invented: the host only keeps the
 * email a device paired with, so that is all that can be shown.
 *
 * When the account is in use the Codync account supplies the avatar instead, and this is unused.
 */

const NAME_KEY = 'localProfileName'
const AVATAR_KEY = 'localProfileAvatar'
/** Whatever macOS can show in an <img>; HEIC is what iPhone photos arrive as after conversion. */
const IMAGE_EXTENSIONS = /^\.(png|jpe?g|gif|webp|heic|heif|tiff?)$/i
/** A picture bigger than this is refused rather than turned into a huge base64 string. */
const MAX_AVATAR_BYTES = 16 * 1024 * 1024

const AVATAR_PREFIX = 'avatar-'

function dataFolder() {
  return app.getPath('userData')
}

/** The saved name, or null for the default. */
export function localProfileName(): string | null {
  const value = prefs.get(NAME_KEY)
  return typeof value === 'string' && value.trim() !== '' ? value.trim().slice(0, 60) : null
}

/** The avatar file, when the recorded path still exists and is a file. */
function avatarFile(): string | null {
  const value = prefs.get(AVATAR_KEY)
  if (typeof value !== 'string' || value === '') return null
  try {
    return statSync(value).isFile() ? value : null
  } catch {
    return null
  }
}

function mimeFor(path: string) {
  switch (extname(path).toLowerCase()) {
    case '.png': return 'image/png'
    case '.gif': return 'image/gif'
    case '.webp': return 'image/webp'
    case '.heic':
    case '.heif': return 'image/heic'
    case '.tif':
    case '.tiff': return 'image/tiff'
    default: return 'image/jpeg'
  }
}

/** The avatar as a data: URL, so the renderer (served from app.asar) can draw it. */
function avatarDataURL(): string | null {
  const file = avatarFile()
  if (!file) return null
  try {
    if (statSync(file).size > MAX_AVATAR_BYTES) return null
    return `data:${mimeFor(file)};base64,${readFileSync(file).toString('base64')}`
  } catch {
    return null
  }
}

function removeOldAvatars(keep?: string) {
  try {
    for (const name of readdirSync(dataFolder())) {
      if (!name.startsWith(AVATAR_PREFIX)) continue
      const path = join(dataFolder(), name)
      if (path === keep) continue
      try {
        unlinkSync(path)
      } catch {}
    }
  } catch {}
}

/** Stores the image the user picked; returns true when an avatar is now in place. */
export function saveLocalAvatar(source: string): boolean {
  try {
    mkdirSync(dataFolder(), { recursive: true })
    const extension = IMAGE_EXTENSIONS.test(extname(source)) ? extname(source).toLowerCase() : '.png'
    const digest = createHash('sha256')
      .update(readFileSync(source))
      .digest('hex')
      .slice(0, 16)
    const target = join(dataFolder(), `${AVATAR_PREFIX}${digest}${extension}`)
    copyFileSync(source, target)
    prefs.set(AVATAR_KEY, target)
    removeOldAvatars(target)
    return true
  } catch (error) {
    console.error('profile: could not save the avatar:', error)
    return false
  }
}

function setName(value: unknown): string | null {
  const text = typeof value === 'string' ? value.trim().slice(0, 60) : ''
  prefs.set(NAME_KEY, text === '' ? undefined : text)
  return localProfileName()
}

/**
 * The Google email the host recorded for its devices (devices.email, spec §4.3). The host only ever
 * keeps the address a device paired with — never a name or a picture — and this computer's devices
 * may predate that column, in which case there is nothing to show.
 */
async function googleEmail(readDevices: () => Promise<{ email?: string | null; connected?: boolean }[]>): Promise<string | null> {
  try {
    const devices = await readDevices()
    const withEmail = devices.filter((d) => typeof d.email === 'string' && d.email !== '')
    const connected = withEmail.find((d) => d.connected)
    return (connected ?? withEmail[0])?.email ?? null
  } catch {
    return null
  }
}

export function registerProfileIPC(readDevices: () => Promise<{ email?: string | null; connected?: boolean }[]>) {
  const state = async (): Promise<LocalProfileState> => ({
    name: localProfileName(),
    avatarURL: avatarDataURL(),
    email: await googleEmail(readDevices),
  })

  ipcMain.handle('profile:state', () => state())

  ipcMain.handle('profile:setName', async (_e, value: unknown) => {
    setName(value)
    return state()
  })

  ipcMain.handle('profile:pickAvatar', async (e) => {
    const window = e.sender && !e.sender.isDestroyed() ? (e.sender as unknown as BrowserWindow) : undefined
    const options: Electron.OpenDialogOptions = {
      title: 'Choose an avatar',
      properties: ['openFile'],
      filters: [{ name: 'Images', extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'heif', 'tif', 'tiff'] }],
    }
    const result = window ? await dialog.showOpenDialog(window, options) : await dialog.showOpenDialog(options)
    const picked = result.canceled ? undefined : result.filePaths[0]
    if (!picked) return state()
    try {
      if (statSync(picked).size > MAX_AVATAR_BYTES) return state()
    } catch {
      return state()
    }
    saveLocalAvatar(picked)
    return state()
  })
}
