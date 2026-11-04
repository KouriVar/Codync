import CodyncKit
import SwiftUI

/// Says which side has to update before this app and a computer can work together. This build
/// ships without app updates (it is compiled from source), so the card only explains the
/// mismatch: no App Store button and no update request sent to the computer.
public struct UpdateNeededCard: View {
    let store: BotStore
    let mismatch: VersionMismatch

    public init(store: BotStore, mismatch: VersionMismatch) {
        self.store = store
        self.mismatch = mismatch
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemixIcon("arrow-down-circle-line")
                .font(.title3)
                .foregroundStyle(Palette.warning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(UpdateNeededText.title(mismatch, host: store.hostName))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Text(UpdateNeededText.detail(mismatch, host: store.hostName,
                                             hostVersion: store.hostVersion?.version, os: store.hello?.os))
                    .font(.footnote)
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// The words every client uses for a version mismatch (the desktop app and the terminal client
/// mirror them).
public enum UpdateNeededText {
    public static func title(_ mismatch: VersionMismatch, host: String) -> String {
        switch mismatch {
        case .updateApp: "This build is out of date"
        case .updateHost: "Update Codync on \(host)"
        }
    }

    public static func detail(_ mismatch: VersionMismatch, host: String, hostVersion: String?, os: String?) -> String {
        switch mismatch {
        case let .updateApp(minimum):
            let runs = hostVersion.map { "\(host) runs Codync \($0) and" } ?? host
            return "\(runs) needs this app to be \(minimum) or newer. This build doesn't update itself; compile a newer one."
        case let .updateHost(version, minimum):
            return "\(host) runs Codync \(version); this app needs \(minimum) or newer. \(how(os: os))"
        }
    }

    /// How to update Codync on a computer this app can't update.
    public static func how(os: String?) -> String { "Update Codync on that computer." }

    /// A computer updating at this app's request.
    public static func updating(host: String) -> String {
        "Updating Codync on \(host). This takes a few minutes."
    }

    /// Why the last update asked of the computer didn't take.
    public static func notUpdated(_ last: HostUpdate, host: String) -> String {
        switch last {
        case let .failed(message): message
        case .requested: "\(host) didn't finish updating. Try again, or update Codync on that computer."
        }
    }
}
