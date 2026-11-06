import { useEffect, useState } from 'react'

/**
 * A right-hand column that outlives its `open` flag for one motion (C0139): closing keeps it
 * mounted while the window slides back to its old width, so the chat's own width never changes in
 * between — the column fades and the window shrinks, and the chat does not move a pixel.
 */
export function useColumnPresence(open: boolean, ms = 300) {
  const [mounted, setMounted] = useState(open)
  useEffect(() => {
    if (open) {
      setMounted(true)
      return
    }
    if (!mounted) return
    const done = setTimeout(() => setMounted(false), ms)
    return () => clearTimeout(done)
  }, [open, mounted, ms])
  return { mounted, closing: mounted && !open }
}
