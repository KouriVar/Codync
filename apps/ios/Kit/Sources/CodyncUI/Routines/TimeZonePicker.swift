import CodyncKit
import SwiftUI

/// Every IANA time zone with its current GMT offset, narrowed as you type; picking one closes it.
struct TimeZonePicker: View {
    let selection: String
    let onPick: (String) -> Void
    @Environment(\.dismissModal) private var dismiss
    @State private var query = ""
    private static let top = "top"

    var body: some View {
        NavigationStack {
            List {
                let zones = TimeZones.search(query)
                if zones.isEmpty {
                    Text(L10n.tr("No matching time zones")).foregroundStyle(.secondary)
                }
                ForEach(zones, id: \.self) { zone in
                    Button { onPick(zone) } label: {
                        HStack(spacing: 10) {
                            Text(zone).foregroundStyle(Palette.text).lineLimit(1)
                            Spacer(minLength: 8)
                            Text(TimeZones.offset(zone)).foregroundStyle(.secondary)
                            Image(systemName: "checkmark").font(.callout.weight(.semibold)).foregroundStyle(Palette.accent)
                                .opacity(zone == selection ? 1 : 0)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .searchable(text: $query, prompt: Text(L10n.tr("Search time zones")))
            .navigationTitle(L10n.tr("Time zone"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("Close")) { dismiss() }
                }
            }
        }
        .tint(.primary)
    }

    private func row(_ zone: String) -> some View {
        Button { onPick(zone) } label: {
            HStack(spacing: 10) {
                Text(zone).foregroundStyle(Palette.text).lineLimit(1)
                Spacer(minLength: 8)
                Text(TimeZones.offset(zone)).foregroundStyle(Palette.secondary)
                Image(systemName: "checkmark").font(.callout.weight(.semibold)).foregroundStyle(Palette.accent)
                    .opacity(zone == selection ? 1 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityAddTraits(zone == selection ? .isSelected : [])
    }
}
