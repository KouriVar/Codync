import SwiftUI
import CodyncKit
import CodyncUI

struct LanguageSettings: View {
    @AppStorage(AppLanguage.storageKey, store: AppLanguage.defaults) private var storedLanguage = AppLanguage.system.rawValue

    private var selection: Binding<AppLanguage> {
        Binding(get: { AppLanguage(rawValue: storedLanguage) ?? .system }, set: { AppLanguage.setPreference($0) })
    }

    var body: some View {
        Picker(L10n.tr("App language"), selection: selection) {
            ForEach(AppLanguage.allCases) { language in
                Text(AppLanguage.menuTitle(language, preference: selection.wrappedValue, systemIsChinese: AppLanguage.systemIsChinese()))
                    .tag(language)
            }
        }
        .pickerStyle(.navigationLink)
    }
}
