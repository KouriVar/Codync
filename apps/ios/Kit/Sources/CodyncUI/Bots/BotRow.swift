import CodyncKit
import SwiftUI

public struct BotRow: View {
    let bot: Bot
    let manuallyUnread: Bool
    @Environment(BotStore.self) private var model

    public init(bot: Bot, manuallyUnread: Bool = false) {
        self.bot = bot
        self.manuallyUnread = manuallyUnread
    }

    // Reference proportions at the default text size: a 48 pt avatar in an 80 pt row.
    @ScaledMetric(relativeTo: .body) private var avatar: CGFloat = 48
    @ScaledMetric(relativeTo: .body) private var rowPadding: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = 17.5
    @ScaledMetric(relativeTo: .subheadline) private var previewSize: CGFloat = 15.5
    @ScaledMetric(relativeTo: .footnote) private var timeSize: CGFloat = 13
    private let lineSpacing: CGFloat = 3

    public var body: some View {
        HStack(spacing: 14) {
            AvatarWithStatus(bot: bot, members: model.members(of: bot), size: avatar)
            VStack(alignment: .leading, spacing: lineSpacing) {
                HStack(alignment: .firstTextBaseline) {
                    if bot.pinned {
                        Image(systemName: "pin.fill").font(.caption2).foregroundStyle(Palette.tertiary)
                    }
                    Text(bot.name)
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .label))
                        .lineLimit(1)
                    if model.screen?.agentBot == bot.id {
                        Image(systemName: "cursorarrow.motionlines")
                            .font(.caption)
                            .foregroundStyle(Palette.accent)
                            .accessibilityLabel("Using the computer")
                    }
                    Spacer(minLength: 8)
                    Text(RelativeTime.day(Date(milliseconds: bot.lastAt)))
                        .font(.system(size: timeSize))
                        .foregroundStyle(bot.unread > 0 ? Color(uiColor: .label) : Color(uiColor: .tertiaryLabel))
                        .fixedSize(horizontal: true, vertical: false)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    preview
                    Spacer(minLength: 4)
                    if bot.unread > 0 { UnreadBadge(count: bot.unread) }
                    else if manuallyUnread {
                        Circle().fill(Palette.accent).frame(width: 9, height: 9)
                            .accessibilityLabel(L10n.tr("Unread"))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, rowPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Live activity while working, otherwise the last message (Grok Bot row behavior).
    @ViewBuilder private var preview: some View {
        if bot.needsInput {
            Label {
                Text(L10n.tr(bot.activity.isEmpty ? "Needs your approval" : bot.activity))
            } icon: {
                ThinkingOrb(state: .listening, size: 16, color: Palette.warning)
            }
                .font(.system(size: previewSize))
                .foregroundStyle(Palette.warning)
                .lineLimit(1)
        } else if bot.isWorking {
            HStack(spacing: 6) {
                ThinkingOrb(size: 13, color: Palette.secondary)
                Text(L10n.tr(bot.activity.isEmpty ? "Working…" : bot.activity))
                    .lineLimit(1)
            }
            .font(.system(size: previewSize))
            .foregroundStyle(Color(uiColor: .secondaryLabel))
        } else if bot.status == "error" {
            Text(MessagePreview.text(bot.lastMessage ?? "Something went wrong"))
                .font(.system(size: previewSize))
                .foregroundStyle(Palette.danger)
                .lineLimit(1)
        } else {
            Text(MessagePreview.text(bot.lastMessage ?? (bot.isGroup ? "\(bot.members.count) bots" : "\(model.backendName(bot.backend)) · \(bot.managedWorkspace ? L10n.tr("Personal workspace") : bot.folderName)")))
                .font(.system(size: previewSize))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .lineLimit(1)
        }
    }
}

/// An unread count in an accent capsule: a bot's, or a folded section's.
public struct UnreadBadge: View {
    let count: Int

    public init(count: Int) { self.count = count }

    public var body: some View {
        Text("\(count)")
            .font(.caption2.bold())
            .foregroundStyle(Palette.onAccent)
            .padding(.horizontal, 6)
            .frame(minWidth: 18, minHeight: 18)
            .background(Palette.accentFill, in: Capsule())
    }
}
