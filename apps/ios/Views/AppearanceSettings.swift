import CodyncKit
import CodyncUI
import SwiftUI
import UIKit

/// The settings row that opens the theme page.
struct AppearanceRow: View {
    let open: () -> Void
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system

    var body: some View {
        Button(action: open) {
            SettingsRow("palette-line", title: L10n.tr("Theme"), value: L10n.tr(appearance.label))
        }
    }
}

/// The pushed page: an inline picker, no system chevron anywhere.
struct AppearancePage: View {
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system

    var body: some View {
        Form {
            Section {
                Picker(selection: $appearance) {
                    ForEach(Appearance.allCases, id: \.self) { Text(L10n.tr($0.label)).tag($0) }
                } label: { EmptyView() }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            AgentLogosToggle()
        }
        .listRowSeparator(.hidden)
    }
}

/// Apply the device preference to the window so already-presented sheets update too.
struct AppearanceWindow: UIViewRepresentable {
    let appearance: Appearance

    func makeUIView(context: Context) -> AppearanceView { AppearanceView() }

    func updateUIView(_ view: AppearanceView, context: Context) {
        view.style = switch appearance {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    final class AppearanceView: UIView {
        var style: UIUserInterfaceStyle = .unspecified {
            didSet { window?.overrideUserInterfaceStyle = style }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            window?.overrideUserInterfaceStyle = style
        }
    }
}
