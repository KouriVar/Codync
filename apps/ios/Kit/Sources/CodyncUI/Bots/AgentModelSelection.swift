import CodyncKit

/// Shared model defaults and option eligibility for the compact and native editors.
struct AgentModelSelection {
    let catalog: AgentModels?
    let selection: String?

    private var agentDefault: AgentModels.Model? {
        catalog?.models.first { $0.name.lowercased().hasPrefix("default") }
    }

    var value: String { selection == agentDefault?.id ? "" : selection ?? "" }

    var choices: [(String, String)] {
        let available = (catalog?.models ?? []).filter { $0.id != agentDefault?.id }
        let current = available.first { $0.id == catalog?.currentModelId }?.name
        let defaultTitle = agentDefault != nil ? L10n.tr("Default")
            : current.map { "\(L10n.tr("Default")) · \($0)" } ?? L10n.tr("Default")
        var result = [("", defaultTitle)]
        result += available.map { ($0.id, $0.name) }
        if let selection, !selection.isEmpty, selection != agentDefault?.id,
           !available.contains(where: { $0.id == selection }) {
            result.append((selection, selection))
        }
        return result
    }

    var selectedModel: AgentModels.Model? {
        catalog?.models.first { $0.id == (selection ?? agentDefault?.id ?? catalog?.currentModelId) }
    }

    var options: [AgentModels.Option] {
        guard !value.isEmpty || catalog?.defaultModelOptions == true else { return [] }
        return selectedModel?.options ?? []
    }
}
