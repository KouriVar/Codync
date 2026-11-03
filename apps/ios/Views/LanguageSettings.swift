import SwiftUI
import CodyncKit
import CodyncUI

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
