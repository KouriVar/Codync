import CodyncKit
import Foundation

/// Localize catalog labels for display while retaining the agent's option/value IDs.
extension AgentModels.Option {
    var localizedTitle: String { L10n.tr(isReasoning ? "Reasoning effort" : name) }

    func localizedName(for value: Value) -> String {
        guard isReasoning else { return L10n.tr(value.name) }
        let normalized = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased().replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        let key: String
        switch normalized {
        case "low": key = "Low"
        case "medium": key = "Medium"
        case "high": key = "High"
        case "minimal": key = "Minimal"
        case "xhigh", "extra high", "very high": key = "Extra high"
        case "max", "maximum": key = "Max"
        case "none": key = "None"
        case "off": key = "Off"
        default: return L10n.tr(value.name)
        }
        return L10n.tr(key)
    }
}
