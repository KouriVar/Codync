import CodyncKit
import CodyncUI
import SwiftUI
import UIKit

struct AppearanceSettings: View {
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system

    var body: some View {
        Picker(L10n.tr("Theme"), selection: $appearance) {
            ForEach(Appearance.allCases, id: \.self) { Text(L10n.tr($0.label)).tag($0) }
        }
        .pickerStyle(.navigationLink)
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
