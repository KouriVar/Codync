# Personal iOS UI preview

The current iOS home screen uses a floating plugin button on the left and a
search capsule on the right, following the supplied Grok Bot reference. Search
filters cached bot/group names and their most recent message previews; it is
not a full conversation-history search. The plugin button opens the current
computer's Extensions page, or computer management when no computer is paired.
State and Settings are temporarily housed in the top-left avatar sheet, alongside
Account, using a native segmented Picker. The earlier experimental 测试 tab stays
hidden.
The other clients are unaffected: this is an iOS-only UI experiment requested
for this fork, with no host or protocol changes.

Use `ui/ios-customization`; no release or merge into `main` is needed for this
preview. The upstream version is retained until a release is prepared.

Generate the project with `xcodegen generate --spec apps/project.yml`, then build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build \
  -project apps/Codync.xcodeproj -scheme 'iOS Dev' -configuration DevDebug \
  -derivedDataPath build/dd -destination 'platform=iOS,id=<device-udid>' \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM=<your-team-id> \
  CODYNC_ENV=ui-preview 'CODYNC_APP_NAME=Codync UI 测试' \
  CODYNC_IOS_BUNDLE_ID=com.suiyikou.codync.uipreview \
  CODYNC_APP_GROUP=group.com.suiyikou.codync.uipreview \
  CODYNC_KEYCHAIN_GROUP=com.suiyikou.codync.uipreview \
  CODYNC_URL_SCHEME=codync-ui-preview \
  CODE_SIGN_ENTITLEMENTS=ios/Resources/UIPreview.entitlements
```

Replace the identifiers if using a different developer account. For a simulator,
use a simulator destination and omit the two provisioning flags and team setting.
The separate app identity and App Group keep the official app's data separate.
The preview configuration has no official account/cloud credentials and omits
Apple sign-in and push capabilities. It supports account-free QR pairing with
the installed official 2.34.2 host: the QR's one-time code and host identity key
authorize the connection, and the phone stores its device key locally. Existing
account-backed builds still send their cloud-issued certificate. Hosts that
require an account certificate can reject local pairing; do not update the host
assuming that QR-only pairing will keep working. Cloud account discovery and
official push notifications are not available in this local build.

Install the built app with `xcrun devicectl device install app --device <device-udid>
'build/dd/Build/Products/DevDebug-iphoneos/Codync UI 测试.app'`.
Open it, choose Get started, continue to scanning, then scan a fresh QR from
the Mac's Pair iPhone menu. Use the same local network for direct connectivity.
Skip remains available when you only want to inspect the home screen.
Earlier builds were installed directly without interaction tests at the user's
request. For the native Bot profile redesign, the user agreed to a visual check
through Device Hub. A successful build or installation alone does not establish
that a changed flow works.

## Native Bot profile (C0017)

Tap a Bot's name in its conversation to open the full-page profile. The previous
four tabs and outlined cards are replaced by a centered avatar/name/Edit header,
native grouped rows for routines, library and computer, and a notification switch.
The system back button returns to the conversation. Share exports the existing
Bot template; More opens instructions/agent, workspace/permissions,
capabilities/plugins and memory. Existing routine and library operations remain
available through the new native list containers.

Edit opens a native form for name and avatar. Its Done button saves changes to
the computer; backing out discards the draft. The advanced forms also save on
Done. These drafts preserve live host updates to untouched fields. Notifications
and computer/memory switches retain their immediate-update behavior. The avatar
upload feature retains its existing account/service requirements and immediate
upload behavior (it is not part of the draft committed on Done). The local
preview still has no official push capability: exposing the Bot notification
preference does not add cloud push support.

This redesign targets the existing Bot profile reached from a conversation.
Bot/group creation now uses the native form described in C0024 below. The separate
roster context-menu editor and group settings retain their previous forms.
Voice input has not been reintroduced.


## Navigation smoke check (C0018)

Debug builds accept `CODYNC_PROFILE_PREVIEW=details` or `edit` as a launch-only
environment variable. The app opens the current account/computer's lead Bot and
the corresponding native page through the real navigation stack. It sends no
chat message and saves no Bot settings. Normal conversation read receipts may
still be sent. Relaunch without the variable to restore normal navigation; the
preview choice is not persisted. This hook is excluded from release builds.

Every native Bot destination explicitly receives the originating `BotStore`.
The root stack stores `[BotReference]`, so subpages use direct destinations
rather than adding another value type to that path.

## Extensions and catalog labels (C0019, C0020)

The Extensions entry sheet now owns a native NavigationStack, navigation-bar
close/credentials buttons, native search and a segmented Picker. Its content
insets are 20 pt on each side (previously 44 pt). The existing agent tile grid,
connector/skill actions, credentials and installation sheets remain available.
Installed connectors/skills use a native pushed title and back navigation.
Connector searches reload after 300 ms without typing; agent and skill filtering
remains immediate.

Custom image UI explicitly uses the app's translation table, including its
buttons, format/size guidance, immediate-save note and accessibility labels.
Known model option labels and reasoning levels use localized display names in
the native form, compact picker and slider; underlying IDs and submitted values
are unchanged. Provider/model names and unknown catalog labels remain as supplied.

## Avatar sheet (C0021)

The home avatar opens a native NavigationStack with Account / State / Settings
segments and a system close button. Account uses a native grouped form, the same
local default avatar as the home screen, and the existing QR pairing and account
flows. Cloud sign-in actions still depend on the build's account configuration.

State restores the widget, Live Activity and Dynamic Island galleries using a
second native segmented Picker. Its chart button opens usage; usage links also
open this segment and the usage sheet. Existing preview drawings and settings
inside the galleries are retained. The widget setup animation runs only while
its gallery and the State segment are visible. Lock Screen widget navigation
shares the sheet's native stack.

Settings restores the former device preferences with native Form sections,
navigation-link pickers, switches and confirmations. Each account gets a fresh
settings view so its selected shortcut lead is read from the correct context.
No setting is changed merely by opening or switching segments. The panels stay
alive while the sheet is open; this is a temporary navigation arrangement.

For Debug-only navigation checks, launch with `CODYNC_ACCOUNT_PANE=account`,
`state` or `settings`. The selection is launch-only and does not save preferences.

## Home roster proportions and top edge (C0022, C0023)

The home roster follows the supplied 1206×2622 Grok Bot reference. At the default
text size, each row has a 48 pt avatar and 16 pt vertical padding (80 pt total),
14 pt between avatar and text, and 3 pt between title and preview. The title is
17.5 pt semibold, preview 15.5 pt, and timestamp 13 pt. The main sizes scale with
Dynamic Type. Content insets are 20 pt leading / 22 pt trailing and 12 pt at the
top. System label colors provide the reference's lighter preview/timestamp.
Working, approval, error, unread, pinned and screen-use indicators remain intact.

The home List explicitly sets `.scrollEdgeEffectStyle(.soft, for: .top)` to retain
the progressive top blur on iOS 27. It uses Apple's public iOS 26+ API rather
than a separate blur overlay. Other pages and the bottom bar are unchanged.
Apple explains the iOS 27 automatic-style change in
[Modernize your UIKit app](https://developer.apple.com/videos/play/wwdc2026/278/);
see also [scrollEdgeEffectStyle](https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle(_:for:)).
The user confirmed the installed build 41 layout and effect on the real device.

## Native creation and delete confirmation (C0024, C0025)

New Bot uses a native NavigationStack, inline title, system close/Create toolbar
buttons and grouped Form sections for the preview, name, appearance and computer.
Multiple computers use a navigation-link Picker. Offline guidance, default agent
selection and saving/error handling are retained. Saving disables editing and
interactive dismissal. New group chat shares the same native container and keeps
its existing member selection and default-name behavior.

Avatar shapes use a 12×3 pt capsule below the selected shape instead of a ring.
The indicator slot is reserved for every shape so selection does not move the
grid. Color swatches retain their circular selection ring and have at least a
44×44 pt hit target. The shared picker also updates the existing Bot avatar editor.

Roster deletion uses SwiftUI's native alert with a destructive action and Cancel.
The title is localized, including the Bot name; deleting still uses the same
computer/store and retains the existing group/file explanations.

Debug launch variables support read-only visual checks: `CODYNC_CREATE_PREVIEW=bot`
opens the real creation form without auto-focusing the keyboard;
`CODYNC_DELETE_PREVIEW=1` opens the first eligible Bot's confirmation and blocks
its destructive action while that flag is active. Neither flag persists or is
included in release builds. Relaunch without flags for ordinary operation.

Build 42 compiled, signed, installed and launched on the paired iPhone. Device
Hub's Computer Use endpoint repeatedly timed out, so final screenshots and live
interaction checks were not completed. No Bot was created or deleted for checking.
