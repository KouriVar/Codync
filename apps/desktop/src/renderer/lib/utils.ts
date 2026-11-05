import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

/**
 * Joins class names and lets later Tailwind utilities win over earlier ones (`tailwind-merge`),
 * the helper every shadcn/ui component is written against.
 */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
