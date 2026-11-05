import { useCallback, useEffect, useState } from 'react'
import { Icon } from '../../components/Icon'
import { HStack, VStack } from '../../components/Stack'
import { Text } from '../../components/Text'
import { Button } from '../../components/ui/button'
import { Card } from '../../components/ui/card'
import { Input } from '../../components/ui/input'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../../components/ui/tabs'
import { useTr } from '../../lib/use-language'
import { useStore } from '../../store/context'
import { authorLabel, type MemoryEntry, type MemoryLayer, type MemoryView } from '../../store/memory-store'
import { relativeTime } from '../thread/chat-items'
import './memory.css'
import './memory-manage.css'

type Section = 'yours' | 'bot' | 'log'

/** One line of what the bot did on its own (C0105). */
interface ActionLog {
  at: number
  routine: string
  status: string
  summary: string
}

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
  const [log, setLog] = useState<ActionLog[] | null>(null)

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

  // Load the action log when its tab is open (C0105).
  useEffect(() => {
    if (section !== 'log') return
    let live = true
    void (async () => {
      try {
        const client = await store.ready()
        const res = await client.call<{ entries: ActionLog[] }>('proactiveLog', {})
        if (live) setLog(res.entries)
      } catch (e) {
        if (live) setError(friendly(e))
      }
    })()
    return () => { live = false }
  }, [section, store, tr])

  const sections: { id: Section; label: string }[] = [
    ...(view?.shared ? [{ id: 'yours' as const, label: 'About you' }] : []),
    { id: 'bot', label: 'This bot' },
    { id: 'log', label: 'Action log' },
  ]

  const saveEdit = async (entry: MemoryEntry) => {
    const text = draft.trim()
    if (!text) return
    if (await run('memoryEdit', { shared: section === 'yours', id: entry.id, text })) {
      setEditing(null)
      setDraft('')
    }
  }
  const doDelete = async (entry: MemoryEntry) => {
    if (await run('memoryDelete', { shared: section === 'yours', id: entry.id })) setConfirm(null)
  }
  const doAdd = async () => {
    const text = adding.trim()
    if (!text) return
    if (await run('memoryAdd', { shared: section === 'yours', text })) setAdding('')
  }

  /** A memory layer's facts (shared "About you" or the bot's own), rendered as Card rows. */
  const renderMemory = (layer: MemoryLayer | undefined, isYours: boolean) => {
    if (!layer) return null
    return (
      <>
        <p className="memory-muted">
          {tr(isYours
            ? 'About you — your name, time zone, people and lasting preferences, shared by every bot. {used} of {cap} in use.'
            : 'This bot — only what this bot itself learned about you. {used} of {cap} in use.')
            .replace('{used}', String(layer.used)).replace('{cap}', String(layer.cap))}
        </p>
        {layer.entries.length === 0 ? (
          <div className="memory-empty">
            <span>{tr(isYours ? 'Nothing shared yet.' : 'Nothing yet. What this bot learns about you shows up here.')}</span>
          </div>
        ) : null}
        <VStack gap={4}>
          {layer.entries.map((entry) => (
            <Card className="memory-manage-row" key={entry.id}>
              {editing === entry.id ? (
                <>
                  <Input
                    className="memory-manage-input"
                    value={draft}
                    autoFocus
                    onChange={(e) => setDraft(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter') void saveEdit(entry)
                      if (e.key === 'Escape') { setEditing(null); setDraft('') }
                    }}
                  />
                  <Button variant="ghost" size="icon" title={tr('Save')} aria-label={tr('Save')} onClick={() => void saveEdit(entry)} disabled={busy}>
                    <Icon name="checkmark" size={14} weight="medium" />
                  </Button>
                  <Button variant="ghost" size="icon" title={tr('Cancel')} aria-label={tr('Cancel')} onClick={() => { setEditing(null); setDraft('') }}>
                    <Icon name="xmark" size={14} weight="medium" />
                  </Button>
                </>
              ) : confirm === entry.id ? (
                <>
                  <Text className="memory-manage-text" tone="danger">{tr('Delete this memory?')}</Text>
                  <Button variant="ghost" size="icon" title={tr('Delete')} aria-label={tr('Delete')} onClick={() => void doDelete(entry)} disabled={busy}>
                    <Icon name="checkmark" size={14} weight="medium" />
                  </Button>
                  <Button variant="ghost" size="icon" title={tr('Cancel')} aria-label={tr('Cancel')} onClick={() => setConfirm(null)}>
                    <Icon name="xmark" size={14} weight="medium" />
                  </Button>
                </>
              ) : (
                <>
                  <span className="memory-manage-text" title={entry.text}>{entry.text}</span>
                  <small className="memory-manage-meta">{authorLabel(entry, (id) => store.authorName(id))} · {relativeTime.day(entry.updatedAt, tr)}</small>
                  <Button variant="ghost" size="icon" title={tr('Edit')} aria-label={tr('Edit')} onClick={() => { setEditing(entry.id); setDraft(entry.text); setConfirm(null) }}>
                    <Icon name="pencil" size={14} weight="medium" />
                  </Button>
                  <Button variant="ghost" size="icon" title={tr('Delete')} aria-label={tr('Delete')} onClick={() => { setConfirm(entry.id); setEditing(null) }}>
                    <Icon name="trash" size={14} weight="medium" />
                  </Button>
                </>
              )}
            </Card>
          ))}
        </VStack>
        <HStack gap={6} className="memory-manage-add">
          <Input
            className="memory-manage-input"
            value={adding}
            placeholder={tr('Add a memory…')}
            onChange={(e) => setAdding(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') void doAdd() }}
          />
          <Button size="sm" onClick={() => void doAdd()} disabled={busy || !adding.trim()}>{tr('Remember this')}</Button>
        </HStack>
      </>
    )
  }

  return (
    <div className="memory-panel memory-manage">
      <Tabs
        value={section}
        onValueChange={(next) => { setSection(next as Section); setEditing(null); setConfirm(null) }}
      >
        <TabsList aria-label={tr('Memory')}>
          {sections.map((item) => (
            <TabsTrigger key={item.id} value={item.id}>{tr(item.label)}</TabsTrigger>
          ))}
        </TabsList>
        {error ? <p role="alert" className="memory-error">{error}</p> : null}
        {!view && !error ? <p className="memory-muted">{tr('Loading memory…')}</p> : null}
        <TabsContent value="yours">{renderMemory(view?.yours, true)}</TabsContent>
        <TabsContent value="bot">{renderMemory(view?.bot, false)}</TabsContent>
        <TabsContent value="log">
          {view ? (
            <>
              {!log ? <p className="memory-muted">{tr('Loading…')}</p> : null}
              {log && log.length === 0 ? <div className="memory-empty"><span>{tr('Nothing done on its own yet.')}</span></div> : null}
              {log && log.length > 0 ? (
                <VStack gap={4}>
                  {log.map((e, i) => (
                    <div className="memory-manage-row memory-manage-log" key={`${e.at}-${i}`}>
                      <span className="memory-manage-text" title={e.summary}>
                        <b>{tr(e.routine)}</b> · {relativeTime.day(e.at, tr)}{e.summary ? ` — ${e.summary}` : ''}
                      </span>
                      <small className={e.status === 'failed' ? 'memory-manage-meta memory-attention' : 'memory-manage-meta'}>
                        {e.status === 'failed' ? tr('failed') : tr('done')}
                      </small>
                    </div>
                  ))}
                </VStack>
              ) : null}
            </>
          ) : null}
        </TabsContent>
      </Tabs>
    </div>
  )
}
