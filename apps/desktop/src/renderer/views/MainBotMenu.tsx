import { createContext, useContext, useRef, useState } from 'react'
import type { MenuItem } from '../components/Overlay'
import type { SettingsPage } from './settings/SettingsView'

/**
 * What the main bot's menu can reach (C0096). The left sidebar is gone on the Mac, so every entry
 * point it held moves in here; the window's `ChatSplitView` owns the handlers and passes them down.
 * Nothing here acts on its own: each row calls the very handler the sidebar row called.
 */
export interface MainMenuActions {
  /** The roster the sidebar held — its sections, right-clicks and footer — in a sheet. */
  openBots: () => void
  /** The Mac's memory page (C0102): the bot's own and the shared facts, editable. */
  openMemory: () => void
  /** The proactive-report times (C0105). */
  openProactive: () => void
  openSearch: () => void
  openNewBot: () => void
  openNewGroup: () => void
  openImport: () => void
  openExtensions: () => void
  openSettings: (page: SettingsPage) => void
  openAccount: () => void
  /** 电脑访问 (Codync Screen): the sheet the menu bar's “Set up computer access…” opens. */
  openAccess: () => void
  /** The same connection summary and choices the sidebar's header showed. */
  connection: { text: string; items: () => MenuItem[] }
}

export const MainMenuActionsContext = createContext<MainMenuActions | null>(null)

/** The window's menu actions, or null where the sidebar still stands (Linux and Windows). */
export function useMainMenuActions() {
  return useContext(MainMenuActionsContext)
}

/** Which list the menu shows: its three groups, the uncommon rows, or the connection choices. */
type MenuPage = 'main' | 'more' | 'connection'

/**
 * The menu over the main bot's name button. Three groups split by a rule: the conversation's own,
 * then the other bots, then the app. Ten rows show at most; the uncommon ones wait behind 更多.
 */
export function useMainBotMenu(conversation: {
  onRoutines: () => void
  onFullConversation: () => void
  onDetails: () => void
  /** C0128: asks the main bot for the pending-items digest, in its chat. */
  onPendingDigest: () => void
}) {
  const actions = useMainMenuActions()
  const ref = useRef<HTMLButtonElement>(null)
  const [open, setOpen] = useState(false)
  const [page, setPage] = useState<MenuPage>('main')
  const close = () => {
    setOpen(false)
    setPage('main')
  }
  const back = (): MenuItem => ({ title: 'Back', icon: 'chevron.left', keepsOpen: true, action: () => setPage('main') })
  const more = (): MenuItem => ({ title: 'More', icon: 'ellipsis', keepsOpen: true, action: () => setPage('more') })
  const items = (): MenuItem[] => {
    if (!actions) return []
    if (page === 'more') {
      return [
        back(),
        { title: 'Full conversation', icon: 'list.bullet.rectangle', divider: true, action: conversation.onFullConversation },
        { title: 'New group chat', icon: 'person.2', action: actions.openNewGroup },
        { title: 'Import bots…', icon: 'square.and.arrow.down', action: actions.openImport },
        { title: 'Extensions', icon: 'square.grid.2x2', action: actions.openExtensions },
        { title: 'Network', icon: 'desktopcomputer', action: () => actions.openSettings('network') },
        { title: 'Proactive reports', icon: 'clock', action: actions.openProactive },
        { title: 'Check for updates', icon: 'arrow.down.circle', action: () => void window.codync.updates.check() },
      ]
    }
    if (page === 'connection') return [back(), ...actions.connection.items()]
    // The bot's own conversation, then the other bots, then the app itself — a rule between each.
    const own: MenuItem[] = [
      { title: '待你处理汇总', icon: 'checklist', action: conversation.onPendingDigest },
      { title: 'Routines', icon: 'clock', action: conversation.onRoutines },
      { title: 'Memory', icon: 'brain', action: () => actions.openMemory() },
      { title: 'Conversation details', icon: 'info.circle', action: conversation.onDetails },
    ]
    const bots: MenuItem[] = [
      { title: 'Bots', icon: 'person.2', divider: true, action: actions.openBots },
      { title: 'New bot', icon: 'plus', action: actions.openNewBot },
      { title: 'Search', icon: 'magnifyingglass', action: actions.openSearch },
    ]
    const app: MenuItem[] = [
      { title: 'Connection status', icon: 'network', detail: actions.connection.text, keepsOpen: true, action: () => setPage('connection') },
      { title: 'Computer access', icon: 'hand.raised', action: actions.openAccess },
      { title: 'Settings', icon: 'gearshape', action: () => actions.openSettings('general') },
      { title: 'Account', icon: 'person.crop.circle', action: actions.openAccount },
      { ...more(), divider: true },
    ]
    return [...own, ...bots, ...app]
  }
  return {
    /** Where the menu anchors: the name button. */
    anchor: ref,
    open,
    items,
    toggle: () => setOpen((o) => !o),
    close,
    /** Whether the menu has anything to show: only where the sidebar moved into it. */
    available: actions !== null,
  }
}
