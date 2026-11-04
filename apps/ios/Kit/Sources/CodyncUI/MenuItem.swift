import CodyncKit
import SwiftUI

/// One row in a Codync menu: an action, a choice when `selected` is set, or a submenu.
public struct MenuItem: Identifiable {
    public let id = UUID()
    public var title: String
    public var icon: String?
    /// A picture in the icon's place (an agent's logo).
    public var image: Image?
    public var selected: Bool?
    public var destructive: Bool
    public var divider: Bool
    /// Shows `title` as it is, never translated: a name the user gave (a section's).
    public var verbatim: Bool
    /// The rows of the submenu this row opens ("Move to section ▸") instead of running `action`;
    /// rendered recursively as native system menus.
    public var submenu: [MenuItem] = []
    public var action: () -> Void

    public init(_ title: String, icon: String? = nil, image: Image? = nil, selected: Bool? = nil, destructive: Bool = false,
                divider: Bool = false, verbatim: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.image = image
        self.selected = selected
        self.destructive = destructive
        self.divider = divider
        self.verbatim = verbatim
        self.action = action
    }

    /// A row that opens a submenu of `rows`.
    public init(_ title: String, icon: String? = nil, divider: Bool = false, submenu rows: [MenuItem]) {
        self.init(title, icon: icon, divider: divider) {}
        submenu = rows
    }

    /// `title` as the row shows it: in the app's language, unless `verbatim`.
    func shownTitle(_ translate: (String) -> String = { L10n.tr($0) }) -> String { verbatim ? title : translate(title) }
}

/// A row of emoji above a message's menu (Slack's quick reactions).
public struct ReactionPick {
    public var emoji: [String]
    public var chosen: [String]
    public var toggle: (String) -> Void

    public init(emoji: [String], chosen: [String], toggle: @escaping (String) -> Void) {
        self.emoji = emoji
        self.chosen = chosen
        self.toggle = toggle
    }
}

public extension View {
    /// System positioning and interaction, with a separate, read-only conversation preview.
    func contextActions<Preview: View>(@ViewBuilder preview: () -> Preview,
                                      _ items: @escaping () -> [MenuItem]) -> some View {
        contextMenu {
            ForEach(items()) { item in
                if item.divider { Divider() }
                systemMenuRow(item)
            }
        } preview: { preview() }
    }

    /// Long-press opens the system context menu; `reactions` puts a quick-reaction row on top.
    func contextActions(reactions: ReactionPick? = nil, _ items: @escaping () -> [MenuItem]) -> some View {
        modifier(ContextActions(items: items, reactions: reactions))
    }
}

private struct ContextActions: ViewModifier {
    let items: () -> [MenuItem]
    let reactions: ReactionPick?

    func body(content: Content) -> some View {
        content.contextMenu {
            if let reactions {
                ControlGroup {
                    ForEach(reactions.emoji, id: \.self) { emoji in
                        let chosen = reactions.chosen.contains(emoji)
                        Toggle(isOn: Binding(get: { chosen }, set: { _ in reactions.toggle(emoji) })) { Text(emoji) }
                    }
                }
                .controlGroupStyle(.palette)
            }
            ForEach(items()) { item in
                if item.divider { Divider() }
                systemMenuRow(item)
            }
        }
    }
}

/// A `MenuItem` inside a system `Menu` or `contextMenu`; a submenu opens its rows in a system
/// `Menu`, including nested menus.
@MainActor private func systemMenuRow(_ item: MenuItem) -> some View { SystemMenuRow(item: item) }

private struct SystemMenuRow: View {
    let item: MenuItem
    var body: some View {
        if item.submenu.isEmpty {
            systemMenuAction(item)
        } else {
            Menu {
                ForEach(item.submenu) { row in
                    if row.divider { Divider() }
                    SystemMenuRow(item: row)
                }
            } label: { menuLabel(item) }
        }
    }
}

/// A `MenuItem` that runs its action: choices as checkmarked toggles.
@ViewBuilder private func systemMenuAction(_ item: MenuItem) -> some View {
    let role: ButtonRole? = item.destructive ? .destructive : nil
    if let selected = item.selected {
        // The binding's setter must be Sendable, but SwiftUI only calls it from the menu, on the
        // main thread where the action was made.
        nonisolated(unsafe) let action = item.action
        Toggle(isOn: Binding(get: { selected }, set: { _ in action() })) { menuLabel(item) }
    } else {
        Button(role: role, action: item.action) { menuLabel(item) }
            .tint(item.destructive ? .red : nil)
    }
}

@ViewBuilder private func menuLabel(_ item: MenuItem) -> some View {
    let title = item.shownTitle()
    if let image = item.image {
        SwiftUI.Label { Text(title) } icon: { image }
    } else if let icon = item.icon {
        SwiftUI.Label { Text(title) } icon: { MenuGlyph(symbol: icon, destructive: item.destructive) }
    } else {
        Text(title)
    }
}

/// A button that opens the system menu.
public struct DropdownMenu<Label: View>: View {
    let items: () -> [MenuItem]
    let label: Label

    public init(items: @escaping () -> [MenuItem], @ViewBuilder label: () -> Label) {
        self.items = items
        self.label = label()
    }

    public var body: some View {
        // The system menu: it anchors correctly inside sheets and scroll views, where an overlay can't.
        Menu {
            ForEach(items()) { item in
                if item.divider { Divider() }
                systemMenuRow(item)
            }
        } label: { label }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
    }
}

/// One of the icon-only shortcut buttons a long-press menu shows in a row above its rows
/// (the system's Cut/Copy/Paste strip).
public struct QuickAction: Identifiable {
    public let id = UUID()
    public let title: String
    public let icon: String
    public let action: () -> Void

    public init(_ title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
}

public extension View {
    /// A context menu with a row of icon-only quick actions on top, a divider, then the rows.
    func contextActions<Preview: View>(quick: [QuickAction], @ViewBuilder preview: () -> Preview,
                                       _ items: @escaping () -> [MenuItem]) -> some View {
        contextMenu {
            if !quick.isEmpty {
                ControlGroup {
                    ForEach(quick) { action in
                        Button(action: action.action) {
                            Label {
                                Text(action.title)
                            } icon: {
                                MenuGlyph(symbol: action.icon, destructive: false)
                            }
                            .labelStyle(.titleAndIcon)
                        }
                        .accessibilityLabel(action.title)
                    }
                }
                Divider()
            }
            ForEach(items()) { item in
                if item.divider { Divider() }
                systemMenuRow(item)
            }
        } preview: {
            preview()
        }
    }
}

/// A menu row's icon: Remix when we have a mapping, otherwise the SF Symbol.
private struct MenuGlyph: View {
    let symbol: String
    let destructive: Bool

    var body: some View {
        // System menus only keep Image icons; a Text glyph (RemixIcon) is dropped, so render
        // the glyph into a template UIImage instead.
        if RemixFont.has(symbol) {
            RemixImage(symbol, size: 17)
                .foregroundStyle(destructive ? Color.red : Color.primary)
        } else if let remix = RemixSymbolMap.remix(for: symbol) {
            RemixImage(remix, size: 17)
                .foregroundStyle(destructive ? Color.red : Color.primary)
        } else {
            Image(systemName: symbol)
                .foregroundStyle(destructive ? Color.red : Color.primary)
        }
    }
}
