import SwiftUI
import CodyncKit
import CodyncUI

/// The settings row that opens the language page.
struct LanguageRow: View {
    let open: () -> Void
    @AppStorage(AppLanguage.storageKey, store: AppLanguage.defaults) private var storedLanguage = AppLanguage.system.rawValue

    private var selection: Binding<AppLanguage> {
        Binding(get: { AppLanguage(rawValue: storedLanguage) ?? .system }, set: { AppLanguage.setPreference($0) })
    }

    var body: some View {
        Button(action: open) {
            SettingsRow("translate-2", title: "语言",
                        value: AppLanguage.menuTitle(selection.wrappedValue, preference: selection.wrappedValue, systemIsChinese: AppLanguage.systemIsChinese()))
        }
    }
}

/// The pushed page: an inline picker of every language.
struct LanguagePage: View {
    @AppStorage(AppLanguage.storageKey, store: AppLanguage.defaults) private var storedLanguage = AppLanguage.system.rawValue

    private var selection: Binding<AppLanguage> {
        Binding(get: { AppLanguage(rawValue: storedLanguage) ?? .system }, set: { AppLanguage.setPreference($0) })
    }

    var body: some View {
        Form {
            Section {
                Picker(selection: selection) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(AppLanguage.menuTitle(language, preference: selection.wrappedValue, systemIsChinese: AppLanguage.systemIsChinese()))
                            .tag(language)
                    }
                } label: { EmptyView() }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                // UIKit reads AppleLanguages once at launch, so the text edit menu follows on the
                // next start, not the moment the picker changes.
                Text(L10n.tr("Restart the app for the new language to take effect"))
            }
        }
        .listRowSeparator(.hidden)
    }
}
