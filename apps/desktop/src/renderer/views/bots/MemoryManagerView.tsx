import { useCallback, useEffect, useState } from 'react'
import { Button, IconButton, TabChoice } from '../../components/Controls'
import { HStack, VStack } from '../../components/Stack'
import { Text } from '../../components/Text'
import { useTr } from '../../lib/use-language'
import { useStore } from '../../store/context'
import { authorLabel, type MemoryEntry, type MemoryView } from '../../store/memory-store'
import { relativeTime } from '../thread/chat-items'
import './memory.css'
import './memory-manage.css'

type Section = 'yours' | 'bot'

/**
 * The Mac's memory page (C0102): what the bot knows, opened from the main bot's menu. Unlike the
 * read-only card in a bot's details, each fact here can be edited or deleted, and a new one added —
 * through the host's additive `memoryAdd`/`memoryEdit`/`memoryDelete`, which write the same
 * `MEMORY.md` dreaming and the bot's own tools write. Nothing about how memory is read changes.
 */
export function MemoryManagerView({ botId }: { botId: string }) {
  const tr = useTr()
  const store = useStore()
  const [view, setView] = useState<MemoryView | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [section, setSection] = useState<Section>('bot')
  const [editing, setEditing] = useState<number | null>(null)
  const [draft, setDraft] = useState('')
  const [confirm, setConfirm] = useState<number | null>(null)
  const [adding, setAdding] = useState('')

  /** An older host answers "unknown method"; say so plainly instead of showing the raw wire error. */
  const friendly = (e: unknown) => {
    const text = e instanceof Error ? e.message : String(e)
    return /unknown method/i.test(text) ? tr('The connected Host is too old to edit memory.') : text
  }

  const load = useCallback(async () => {
    try {
      const client = await store.ready()
      setView(await client.call<MemoryView>('memory', { botId }))
      setError(null)
    } catch (e) {
      setError(friendly(e))
    }
  }, [store, botId, tr])

  useEffect(() => { void load() }, [load])
  // The shared layer can be switched off elsewhere; fall back to the bot's own.
  useEffect(() => { if (section === 'yours' && view && !view.shared) setSection('bot') }, [section, view])

  const run = async (method: string, args: Record<string, unknown>) => {
    setBusy(true)
    try {
      const client = await store.ready()
      await client.call(method, { botId, ...args })
      await load()
      return true
    } catch (e) {
      setError(friendly(e))
      return false
    } finally {
      setBusy(false)
    }
  }

  const shared = section === 'yours'
  const layer = section === 'yours' ? view?.yours : view?.bot
  const sections: { id: Section; label: string }[] = [
    ...(view?.shared ? [{ id: 'yours' as const, label: 'About you' }] : []),
    { id: 'bot', label: 'This bot' },
  ]

  const saveEdit = async (entry: MemoryEntry) => {
    const text = draft.trim()
    if (!text) return
    if (await run('memoryEdit', { shared, id: entry.id, text })) {
      setEditing(null)
      setDraft('')
    }
  }
  const doDelete = async (entry: MemoryEntry) => {
    if (await run('memoryDelete', { shared, id: entry.id })) setConfirm(null)
  }
  const doAdd = async () => {
    const text = adding.trim()
    if (!text) return
    if (await run('memoryAdd', { shared, text })) setAdding('')
  }

  return (
    <div className="memory-panel memory-manage">
      <TabChoice label="Memory" selection={section} options={sections} onChange={(next) => { setSection(next); setEditing(null); setConfirm(null) }} />
      {error ? <p role="alert" className="memory-error">{error}</p> : null}
      {!view && !error ? <p className="memory-muted">{tr('Loading memory…')}</p> : null}
      {view && layer ? (
        <>
          <p className="memory-muted">
            {tr(section === 'yours'
              ? 'About you — your name, time zone, people and lasting preferences, shared by every bot. {used} of {cap} in use.'
              : 'This bot — only what this bot itself learned about you. {used} of {cap} in use.')
              .replace('{used}', String(layer.used)).replace('{cap}', String(layer.cap))}
          </p>
          {layer.entries.length === 0 ? (
            <div className="memory-empty">
              <span>{tr(section === 'yours' ? 'Nothing shared yet.' : 'Nothing yet. What this bot learns about you shows up here.')}</span>
            </div>
          ) : null}
          <VStack gap={4}>
            {layer.entries.map((entry) => (
              <div className="memory-manage-row" key={entry.id}>
                {editing === entry.id ? (
                  <>
                    <input
                      className="memory-manage-input"
                      value={draft}
                      autoFocus
                      onChange={(e) => setDraft(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') void saveEdit(entry)
                        if (e.key === 'Escape') { setEditing(null); setDraft('') }
                      }}
                    />
                    <IconButton title="Save" icon="checkmark" size={26} onClick={() => void saveEdit(entry)} disabled={busy} />
                    <IconButton title="Cancel" icon="xmark" size={26} onClick={() => { setEditing(null); setDraft('') }} />
                  </>
                ) : confirm === entry.id ? (
                  <>
                    <Text className="memory-manage-text" tone="danger">{tr('Delete this memory?')}</Text>
                    <IconButton title="Delete" icon="checkmark" size={26} onClick={() => void doDelete(entry)} disabled={busy} />
                    <IconButton title="Cancel" icon="xmark" size={26} onClick={() => setConfirm(null)} />
                  </>
                ) : (
                  <>
                    <span className="memory-manage-text" title={entry.text}>{entry.text}</span>
                    <small className="memory-manage-meta">{authorLabel(entry, (id) => store.authorName(id))} · {relativeTime.day(entry.updatedAt, tr)}</small>
                    <IconButton title="Edit" icon="pencil" size={26} onClick={() => { setEditing(entry.id); setDraft(entry.text); setConfirm(null) }} />
                    <IconButton title="Delete" icon="trash" size={26} onClick={() => { setConfirm(entry.id); setEditing(null) }} />
                  </>
                )}
              </div>
            ))}
          </VStack>
          <HStack gap={6} className="memory-manage-add">
            <input
              className="memory-manage-input"
              value={adding}
              placeholder={tr('Add a memory…')}
              onChange={(e) => setAdding(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') void doAdd() }}
            />
            <Button onClick={() => void doAdd()} disabled={busy || !adding.trim()}>{tr('Remember this')}</Button>
          </HStack>
        </>
      ) : null}
    </div>
  )
}
