/**
 * The settings URL a renderer asked to open, when it is one macOS Settings pane.
 *
 * `app:openSettings` receives whatever the renderer passed; a caller that names no permission (or
 * one the map has no URL for) sends `undefined`. Reading `.startsWith` on that threw inside the
 * main process, so the check is pulled out here as a plain function with a test.
 */
export function systemSettingsURL(value: unknown): string | null {
  return typeof value === 'string' && value.startsWith('x-apple.systempreferences:') ? value : null
}
