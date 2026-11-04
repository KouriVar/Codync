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

/// What happens once the words are in: send them after a beat, or wait for the button.
public enum VoiceSendMode: String, CaseIterable, Identifiable, Sendable {
    /// The words send themselves after `VoiceSession.confirmWindow`; correcting them stops that.
    case automatic
    /// Nothing leaves until the send button is pressed.
    case manual

    public static let storageKey = "voiceSendMode"

    public var id: String { rawValue }
    public var title: String { self == .automatic ? "Automatic" : "Manual" }
    public var detail: String {
        self == .automatic
            ? "Sends 1.5 seconds after the recording ends. Tap the words to correct them instead."
            : "Nothing is sent until you tap send."
    }

    /// Manual unless the reader picked otherwise.
    public static var stored: VoiceSendMode {
        UserDefaults.standard.string(forKey: storageKey).flatMap(VoiceSendMode.init(rawValue:)) ?? .manual
    }
}

/// The voice sheet's settings: the recognition language, and what happens to the words afterwards.
public struct VoiceLanguageSheet: View {
    @AppStorage(VoiceLanguage.storageKey) private var saved = VoiceLanguage.chinese.rawValue
    @AppStorage(VoiceSendMode.storageKey) private var savedMode = VoiceSendMode.manual.rawValue
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

                Section {
                    ForEach(VoiceSendMode.allCases) { mode in
                        Button {
                            savedMode = mode.rawValue
                            Haptics.impact()
                        } label: {
                            HStack(spacing: 12) {
                                RemixIcon(mode == .automatic ? "send-plane-2-line" : "cursor-line", size: 20)
                                    .foregroundStyle(Palette.secondary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.tr(mode.title))
                                        .foregroundStyle(Palette.text)
                                    Text(L10n.tr(mode.detail))
                                        .font(.footnote)
                                        .foregroundStyle(Palette.secondary)
                                }
                                Spacer(minLength: 8)
                                if savedMode == mode.rawValue {
                                    RemixIcon("check-line", size: 20)
                                        .foregroundStyle(Palette.text)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(L10n.tr("Send mode"))
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
