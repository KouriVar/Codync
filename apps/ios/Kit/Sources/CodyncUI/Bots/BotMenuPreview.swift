import CodyncKit
import SwiftUI

/// No ThreadView here: holding a row must not acknowledge messages as read.
public struct BotMenuPreview: View {
    let bot: Bot
    @Environment(BotStore.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    public init(bot: Bot) { self.bot = bot }

    /// The whole last message (up to 8 lines), lightly stripped of markdown noise — not just its first line.
    private var message: String {
        guard let raw = bot.lastMessage, !raw.isEmpty else { return L10n.tr("No messages yet") }
        return raw
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
    }

    /// Dark mode: a deeper card (#141414) with a slightly lighter bubble (#232323), per design.
    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x14 / 255) : Color(uiColor: .systemBackground)
    }
    private var bubbleBackground: Color {
        colorScheme == .dark ? Color(red: 0x23 / 255, green: 0x23 / 255, blue: 0x23 / 255) : Color(uiColor: .secondarySystemGroupedBackground)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if bot.isGroup { GroupAvatar(members: model.members(of: bot), size: 30) }
                else { CharacterAvatar(bot: bot, size: 30, animated: false) }
                Text(bot.name).font(.headline).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(16)

            Text(message)
                .font(.body)
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 16)
        }
        .frame(width: 320)
        .background(cardBackground)
    }
}
