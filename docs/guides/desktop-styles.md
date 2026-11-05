# Desktop styles

How the desktop renderer (`apps/desktop/src/renderer/`) styles its views. Views hold no styling of their own: text, layout and visuals come from the shared primitives and tokens below, and an inline `style` is left only for values computed at runtime.

## Tokens (`styles/tokens.css`)

Since C0106 every colour, radius, shadow, type size, motion value, spacing step and layout size lives in one file, `apps/desktop/src/renderer/styles/tokens.css` (light and dark). `styles/tailwind.css` maps it into Tailwind/shadcn theme tokens; `styles/theme.css` holds only the structural reset and reads the tokens.

- **Color**: `--text`, `--secondary`, `--tertiary`, `--danger`, `--attention` (status text), `--accent`, surfaces (`--background`, `--surface`, `--panel`, `--bubble-*`, `--chat-*`, `--chrome-fill`, `--composer-fill`), strokes (`--border`, `--chrome-stroke`, `--stroke-strong`, `--outline` for the 1px edge of floating layers: the composer, sheets, dialogs and menus), fills with their ink (`--accent-fill`/`--on-accent`, `--danger-fill`/`--on-danger`, `--warning`/`--on-warning`), delegation status dots (`--status-problem`/`--status-working`/`--status-asking`/`--status-idle`), `--added`/`--removed`, `--code-background`, `--scrim`, the chosen option of a segmented choice or chip (`--chip-on`, `--chip-shadow`). Sheets and dialogs sit on `--sheet` (a step above the page in dark mode) with grouped rows on `--group` and text fields on `--field`, tints that stack; inside `.modal-content` the page tokens point at them (`--background` → `--sheet`, `--surface` and `--bubble-agent` → `--group`, `--bubble-user` → `--field`), so a view styled with the page tokens fits a sheet unchanged. Every color has a light and a dark value. Views use the tokens, or `rgba(var(--text-rgb), a)` for a tint of the text color; a literal only where the color must not follow the theme (white behind a QR code or a favicon). The shadcn names (`--color-background`, `--color-foreground`, `--color-primary`, `--color-muted-foreground`, `--color-border`, …) alias these values so both vocabularies stay one palette.
- **Type ramp**: `--text-large-title` 26, `--text-title` 22, `--text-title2` 17, `--text-title3` 15, `--text-body` 13, `--text-callout` 12, `--text-caption` 11 (points, scaled by the text size preference). `lib/fonts.ts` maps the macOS style names onto it (`headline` and `body` → body, `compactBody` → callout, `subheadline`, `footnote`, `caption`, `caption2`, `compactSecondary` → caption).
- **Radius**: `--radius-xs` 6, `--radius-s` 10, `--radius-m` 12, `--radius-l` 16, `--radius-xl` 22, `--radius-pill`. **Shadow**: `--shadow-s` (resting), `--shadow-m` (floating chrome), `--shadow-l` (menus, panels), `--shadow-xl` (sheets, dialogs).
- **Spacing**: `--space-1` 2, `--space-2` 4, `--space-3` 6, `--space-4` 8, `--space-5` 12, `--space-6` 16, `--space-7` 24, `--space-8` 32.
- **Layout** (the Figma frame, node 54:328): `--chat-max` 888, `--chat-min` 560, `--bubble-max` 560, `--panel-min` 320, `--frame-inset` 6, `--divider-width` 1, `--sidebar-width` 260, `--sidebar-min` 180.
- **Motion**: `--hover`, `--fade`, `--press`, `--morph`, `--layout`, `--ease`, `--ease-out`, `--spring`. The island has its own (`--island-spring`, `--island-fold`) in `views/island/island.css`.

## Primitives (`components/`)

| Need | Use |
| --- | --- |
| Text in a type style and color | `<Text size="caption" tone="secondary" weight="semibold" mono as="div">` (`Text.tsx`). With `size` the weight defaults to regular (bold for `headline`); without it, size and weight come from around it. `truncate` ends one line with an ellipsis, `lines={n}` clamps to n lines, `grow` takes a stack's free space, `tabular` lines digits up |
| A row / a column | `<HStack gap={8}>` (centered vertically; `align="stretch"` or `"baseline"` otherwise) / `<VStack gap={8}>` (`Stack.tsx`); `grow` takes the free space, `shrink` lets it shrink so text inside can truncate; `justify`, `wrap`, `as` |
| Space between stack items | `<Spacer />`, `<Spacer min={8} />` |
| A fixed-width column that centers an icon, so labels line up | `<IconSlot width={18} tone="secondary">` |
| A row's title with a note under it | `RowLabel` (`Controls.tsx`) |
| Reorder by dragging | `pointerDrag` (`lib/pointer-drag.ts`), not native drag and drop: the pointer holds a closed hand, and a roster row lifts as a smaller, translucent copy that settles into its slot |
| A sheet's content | `<SheetPage>` with a `ModalHeader` (`Overlay.tsx`); `ModalHeader` takes an `icon` (an SF Symbol name on a tile, or a logo element), a title that wraps to two lines, a `subtitle` (up to two lines, the rest in its tooltip), and `onClose` when it heads a panel instead of a modal. A `Sheet` without `height` fits its content up to `maxHeight` (and the window); `FormSheet` does that unless `fixed` (content that fills the card or slides in pages that do: a terminal, an agent sheet) |
| One line with an ellipsis on an element that isn't `Text` | `.truncate` |
| Controls | `Controls.tsx`, `Overlay.tsx`, `Icon.tsx`; this fork uses the bundled Remix font on macOS (`remix-icons.ts`, `remix-symbols.json`) and retains the original icon paths on other platforms. `Hairline`, `Pill`, `Switch` and `ProgressBar` take a `className` for a view's own sizing, and a panel beside an anchor is placed with `anchorPlacement` |

## shadcn/ui primitives (`components/ui/`)

Since C0106 the app also carries shadcn/ui primitives (Tailwind v4 + `class-variance-authority` + `tailwind-merge`), all styled from the same tokens: `button` (variants default/secondary/outline/ghost/destructive/link; sizes sm/default/lg/icon), `input`, `textarea`, `card` (Header/Title/Description/Content/Footer), `badge`, `separator`, `tabs` (Radix), `switch` (Radix), `label`. Join classes with `cn()` from `lib/utils.ts`.

- **When to use them**: new UI, and a rewritten surface. When a bespoke component maps cleanly, pass the primitive the existing view class as `className` (e.g. `className="dialog-button"` or `className="bot-chat-panel-send"`) so the verified pixel styling still applies while the markup and behaviour come from the shadcn primitive; when it does not map, keep the bespoke component.
- **Tailwind**: `styles/tailwind.css` imports Tailwind's theme + utility layers **without Preflight** (the app has its own reset in the `@layer base` block of `theme.css`, which sits below the utility layer so primitives can override it). Utilities resolve against the tokens: `bg-background`, `text-muted-foreground`, `border-border`, `bg-primary`, `rounded-lg`, `text-sm`, etc.
- **Not migrated**: the custom title bar / traffic-light band (main-process `BrowserWindow` config), the tray and the native application menu (main process), and Codync Screen (`src/main/screen.ts` + the bundled helper) are desktop-only native chrome and stay as they are; the chat window's own title pill stays a bespoke component because it drives the main bot menu.

## Where a style goes

1. Text styling is `Text` props; layout is `HStack`/`VStack`/`Spacer`.
2. Anything else static (padding, background, radius, size, position, borders) is a class in the view's CSS file, named after the view (`.bot-row`, `.unread-badge`), written with the tokens above.
3. No static inline styles. Inline `style` only for values computed at runtime: a size or color from props or data, a measured width, a transform that follows state. Keep the static part of that element in its class.
4. A pattern repeated across views becomes a primitive or a shared class here; don't copy it.
5. Anything clickable shows the pointing hand (a `:where` rule in `theme.css`, so a view's own `cursor` wins); text fields show the text cursor.
