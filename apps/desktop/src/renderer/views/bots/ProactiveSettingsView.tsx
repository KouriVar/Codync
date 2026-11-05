import { useCallback, useEffect, useState } from 'react'
import { Button } from '../../components/Controls'
import { HStack, VStack } from '../../components/Stack'
import { Text } from '../../components/Text'
import { useTr } from '../../lib/use-language'
import { useStore } from '../../store/context'
import './proactive-settings.css'

interface Times {
  brief: string
  summary: string
  silent: string
}

const FIELDS: { key: keyof Times; title: string; detail: string }[] = [
  { key: 'brief', title: 'Midday report', detail: 'A short note at noon: what is done, and what needs your decision.' },
  { key: 'summary', title: 'Daily summary', detail: 'One full summary in the evening: finished, still open, and what to do next.' },
  { key: 'silent', title: 'Memory tidy', detail: 'Quietly tidies memory at this time and sends nothing.' },
]

/**
 * The proactive-report times (C0105), opened from the main bot's menu. Three times are editable; saving
 * rewrites the lead bot's routines' schedules through the host's additive `proactiveSetTimes`, which takes
 * effect on the next scheduler tick — no restart.
 */
export function ProactiveSettingsView() {
  const tr = useTr()
  const store = useStore()
  const [times, setTimes] = useState<Times | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [saved, setSaved] = useState(false)
  const [busy, setBusy] = useState(false)

  const load = useCallback(async () => {
    try {
      const client = await store.ready()
      const res = await client.call<{ times: Times }>('proactiveSettings', {})
      setTimes(res.times)
      setError(null)
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e))
    }
  }, [store])

  useEffect(() => { void load() }, [load])

  const save = async () => {
    if (!times) return
    setBusy(true)
    try {
      const client = await store.ready()
      const res = await client.call<{ times: Times }>('proactiveSetTimes', { ...times })
      setTimes(res.times)
      setError(null)
      setSaved(true)
      setTimeout(() => setSaved(false), 2200)
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="proactive-settings">
      <Text as="div" size="callout" tone="secondary" className="proactive-lead">
        {tr('Proactive reports run on this computer’s time zone. Changes take effect immediately.')}
      </Text>
      {error ? <p role="alert" className="memory-error">{error}</p> : null}
      {!times && !error ? <p className="memory-muted">{tr('Loading…')}</p> : null}
      {times ? (
        <VStack gap={10} className="proactive-rows">
          {FIELDS.map((field) => (
            <div className="proactive-row" key={field.key}>
              <VStack gap={2} className="proactive-row-text">
                <Text size="body" weight="medium">{tr(field.title)}</Text>
                <Text size="caption" tone="secondary">{tr(field.detail)}</Text>
              </VStack>
              <input
                type="time"
                className="proactive-time"
                value={times[field.key]}
                step={60}
                onChange={(e) => setTimes({ ...times, [field.key]: e.target.value })}
              />
            </div>
          ))}
          <HStack gap={8} align="center" className="proactive-actions">
            <Button onClick={() => void save()} disabled={busy}>{tr('Save')}</Button>
            {saved ? <Text size="footnote" tone="added">{tr('Saved — takes effect immediately')}</Text> : null}
          </HStack>
        </VStack>
      ) : null}
    </div>
  )
}
