import CodyncKit
import SwiftUI

/// Skills, connectors, rules and plugins the agent already has, under Sign in on its sheet.
struct AgentBrings: View {
    let backendId: String
    @Environment(BotStore.self) private var model
    @State private var gear: AgentGear?
    @State private var failed = false
    @State private var skills = false
    @State private var connectors = false
    @State private var rules = false
    @State private var plugins = false

    var body: some View {
        NativeFormSection("What the agent brings") {
            if failed {
                Text(L10n.tr("Couldn't load what this agent brings."))
                    .font(.footnote).foregroundStyle(.red)
            } else if let gear {
                if gear.shows {
                    row("Skills", gear.skills, $skills)
                    row("Connectors", gear.connectors, $connectors)
                    row("Rules", gear.rules, $rules)
                    row("Plugins", gear.plugins, $plugins)
                } else {
                    Text(L10n.tr("Nothing installed")).foregroundStyle(.secondary)
                }
            } else { ProgressView() }
        }
        .task(id: [backendId, model.connection == .online ? "online" : "waiting"]) { await load() }
    }

    @ViewBuilder private func row(_ title: String, _ items: [AgentGearItem], _ open: Binding<Bool>) -> some View {
        if !items.isEmpty {
            DisclosureGroup(isExpanded: open) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name).font(.subheadline)
                        let note = item.description.isEmpty ? item.detail : item.description
                        if !note.isEmpty { Text(note).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            } label: {
                HStack {
                    Label(L10n.tr(title), systemImage: icon(title))
                    Spacer()
                    Text("\(items.count)").foregroundStyle(.secondary)
                }
            }
        }
    }

    private func icon(_ title: String) -> String {
        switch title {
        case "Skills": "book.pages"
        case "Connectors": "point.3.connected.trianglepath.dotted"
        case "Rules": "list.bullet.rectangle"
        default: "square.grid.2x2"
        }
    }

    private func load() async {
        guard model.connection == .online else { return }
        failed = false
        gear = nil
        do {
            gear = try await model.agentBrings(backendId)
        } catch is CancellationError {
        } catch {
            failed = true
        }
    }
}

extension AgentGear {
    fileprivate var shows: Bool { !skills.isEmpty || !connectors.isEmpty || !rules.isEmpty || !plugins.isEmpty }
}
