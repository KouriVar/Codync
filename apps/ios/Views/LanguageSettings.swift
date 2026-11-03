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
            SettingsRow("translate-2", title: L10n.tr("App language"),
                        value: AppLanguage.menuTitle(selection.wrappedValue, preference: selection.wrappedValue, systemIsChinese: AppLanguage.systemIsChinese()))
        }
    }
}

struct LanguageSettings: View {
    @AppStorage(AppLanguage.storageKey, store: AppLanguage.defaults) private var storedLanguage = AppLanguage.system.rawValue

    private var selection: Binding<AppLanguage> {
        Binding(get: { AppLanguage(rawValue: storedLanguage) ?? .system }, set: { AppLanguage.setPreference($0) })
    }

    var body: some View {
        Picker(selection: selection) {
            ForEach(AppLanguage.allCases) { language in
                Text(AppLanguage.menuTitle(language, preference: selection.wrappedValue, systemIsChinese: AppLanguage.systemIsChinese()))
                    .tag(language)
            }
        } label: {
            HStack(spacing: 12) {
                RemixIcon("translate-2", size: 18).frame(width: 22).foregroundStyle(.primary)
                Text(L10n.tr("App language"))
            }
        }
        .pickerStyle(.navigationLink)
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
            }
        }
        .listRowSeparator(.hidden)
    }
}
