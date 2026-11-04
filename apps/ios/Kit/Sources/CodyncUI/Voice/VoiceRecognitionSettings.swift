import CodyncKit
import SwiftUI

/// The language the voice capsule hears. Stored on this device, so the next recording uses it.
public enum VoiceLanguage: String, CaseIterable, Identifiable, Sendable {
    case chinese = "zh-CN"
    case english = "en-US"

    public static let storageKey = "voiceRecognitionLanguage"

    public var id: String { rawValue }
    public var localeIdentifier: String { rawValue }

    /// Shown in the picker as the language names itself.
    public var title: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }

    /// Chinese unless the reader picked otherwise. Read when a recording starts.
    public static var stored: VoiceLanguage {
        UserDefaults.standard.string(forKey: storageKey).flatMap(VoiceLanguage.init(rawValue:)) ?? .chinese
    }
}

/// The capsule's settings sheet: only the recognition language for now. Presented at medium
/// height, so the home stays visible behind it.
public struct VoiceLanguageSheet: View {
    @AppStorage(VoiceLanguage.storageKey) private var saved = VoiceLanguage.chinese.rawValue
    @Environment(\.dismissModal) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(VoiceLanguage.allCases) { language in
                        Button {
                            saved = language.rawValue
                            Haptics.impact()
                        } label: {
                            HStack(spacing: 12) {
                                RemixIcon("translate-2", size: 20)
                                    .foregroundStyle(Palette.secondary)
                                    .frame(width: 28)
                                Text(language.title)
                                    .foregroundStyle(Palette.text)
                                Spacer(minLength: 8)
                                if saved == language.rawValue {
                                    RemixIcon("check-line", size: 20)
                                        .foregroundStyle(Palette.text)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(L10n.tr("Recognition language"))
                } footer: {
                    Text(L10n.tr("The voice capsule turns what you say into text in this language."))
                }
            }
            .navigationTitle(L10n.tr("Voice"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { RemixImage("close-line", size: 24) }
                        .accessibilityLabel(Text(L10n.tr("Close")))
                        .buttonBorderShape(.circle)
                }
            }
        }
        .tint(.primary)
    }
}
