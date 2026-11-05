import type { CSSProperties } from 'react'
import names from './remix-symbols.json'
import codepoints from '../assets/remix/remixicon-codepoints.json'

interface Props {
  name: string
  size: number
  color?: string
  style?: CSSProperties
  className?: string
  scaled?: boolean
  title?: string
}

/** Shared by the source renderer and the installed 2.34.2 renderer overlay. */
export function remixIconProps({ name, size, color, style, className, scaled = true, title }: Props) {
  const remix = (names as Record<string, string>)[name] ?? name
  const hex = (codepoints as Record<string, string>)[remix]
  if (!hex) return null
  const dimension = scaled ? `calc(1.2 * ${size}px * var(--scale))` : `${size * 1.2}px`
  return {
    className: ['remix-icon', className].filter(Boolean).join(' '),
    title,
    role: title ? 'img' : undefined,
    'aria-label': title,
    'aria-hidden': title ? undefined : true,
    style: { width: dimension, height: dimension, fontSize: dimension, color: color ?? 'currentColor', ...style },
    children: String.fromCodePoint(Number.parseInt(hex, 16)),
  }
}
