import CodyncKit
import SwiftUI

/// A routine's settings page: native Form sections, one row per setting, with the schedule
/// preview (including the next run) as the schedule section's footer.
struct RoutineEditorView: View {
    let botId: String
    let routine: Routine?
    /// Called after a save (the routine) or a delete (nil).
    let saved: (Routine?) -> Void
    @Environment(BotStore.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismissModal) private var dismiss
    @State private var name = ""
    @State private var instruction = ""
    @State private var schedule = RoutineScheduleDraft()
    @State private var timeout = "3600"
    @State private var busy = false
    @State private var error: String?
    @State private var advanced = false
    @State private var loaded = false
    @State private var preview: RoutineSchedulePreview?
    @State private var previewError: String?
    @State private var checkedSchedule: RoutineScheduleDraft?
    @State private var confirmDelete = false
    @State private var started = false

    /// Schedule or webhook, as in Claude Code routines. Anything else the bot set up
    /// (a one-off time, an interval, events, several triggers) stays as it is until replaced.
    private var options: [(String, String)] {
        var values = [("cron", "Schedule"), ("webhook", "Webhook")]
        if let routine, keepsOriginal {
            values.insert(("keep", routine.triggerDescriptions.joined(separator: " · ")), at: 0)
        }
        return values
    }

    private var keepsOriginal: Bool {
        guard let routine, routine.triggers.count == 1 else { return routine != nil && !(routine?.triggers.isEmpty ?? true) }
        return !["cron", "webhook"].contains(routine.triggers[0].type)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isOffline && !busy &&
        loaded && checkedSchedule == schedule && previewError == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.tr("Name"), text: $name,
                              prompt: Text(L10n.tr("e.g. Morning summary")))
                    TextField(L10n.tr("Instruction"), text: $instruction, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    Picker(L10n.tr("When to run"), selection: $schedule.kind) {
                        ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                            Text(triggerTitle(option.0, fallback: option.1)).tag(option.0)
                        }
                    }
                    .pickerStyle(.menu)

                    if loaded {
                        triggerFields
                    } else {
                        Label {
                            Text(L10n.tr("Loading schedule…"))
                        } icon: {
                            FormIcon("time-line")
                        }
                        .foregroundStyle(.secondary)
                    }
                } footer: {
                    scheduleFooter
                }

                Section {
                    DisclosureGroup(isExpanded: $advanced) {
                        TextField(L10n.tr("Timeout (seconds)"), text: $timeout)
                            .keyboardType(.numberPad)
                        Text(L10n.tr("A run is stopped after this long. 1 second to 24 hours."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label {
                            Text(L10n.tr("Run settings"))
                        } icon: {
                            FormIcon("settings-3-line")
                        }
                    }
                }

                if let error {
                    Section {
                        Label { Text(error) } icon: { FormIcon("error-warning-line") }
                            .foregroundStyle(Palette.danger)
                            .textSelection(.enabled)
                    }
                }

                if !loaded, error != nil {
                    Section {
                        Button(L10n.tr("Retry loading schedule")) { Task { await loadSchedule() } }
                    }
                }

                if model.isOffline {
                    Section {
                        Label { Text(L10n.tr("Connect to this computer to save your routine.")) }
                            icon: { FormIcon("wifi-off-line") }
                            .foregroundStyle(Palette.danger)
                    }
                }

                if loaded, !model.isOffline,
                   name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                   instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Text(L10n.tr("Enter a name and instruction above to save."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if routine != nil {
                    Section {
                        Button {
                            runNow()
                        } label: {
                            Label {
                                Text(started ? L10n.tr("Started") : L10n.tr("Test run"))
                            } icon: {
                                FormIcon(started ? "check-line" : "play-circle-line")
                            }
                        }
                        .disabled(started || model.isOffline)
                    }
                }

                if routine != nil {
                    Section {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label {
                                Text(L10n.tr("Delete routine"))
                            } icon: {
                                FormIcon("delete-bin-line")
                                    .foregroundStyle(Palette.danger)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.tr(routine == nil ? "Set up a routine" : "Edit routine"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Close")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? L10n.tr("Saving…") : L10n.tr(routine == nil ? "Create" : "Save")) {
                        save()
                    }
                    .disabled(!canSave)
                    .keyboardShortcut("s", modifiers: .command)
                }
            }
            .alert(L10n.tr("Delete routine?"), isPresented: $confirmDelete) {
                Button(L10n.tr("Delete routine"), role: .destructive) { deleteRoutine() }
                Button(L10n.tr("Cancel"), role: .cancel) {}
            } message: {
                Text(L10n.tr("This deletes the routine and stops its future runs. This can't be undone."))
            }
            .task {
                if let routine {
                    name = routine.name
                    instruction = routine.instruction
                    timeout = String(routine.timeoutSeconds ?? 3600)
                }
                await loadSchedule()
            }
            .task(id: schedule) {
                guard loaded else { return }
                do { try await Task.sleep(for: .milliseconds(300)) }
                catch { return }
                await checkSchedule()
            }
        }
        .background(Palette.background)
    }

    // MARK: - Schedule

    @ViewBuilder private var triggerFields: some View {
        switch schedule.kind {
        case "cron":
            cronFields
        case "webhook":
            if let routine, routine.triggers.contains(where: { $0.type == "webhook" || $0.type == "event" }) {
                RoutineWebhookPanel(botId: botId, routineId: routine.id)
            } else {
                Text(L10n.tr("Runs each time something is posted to its URL. Save to get the URL and key."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        default:
            Text(L10n.tr("Set up by the bot. Pick Schedule or Webhook to replace it."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// A frequency with its time, or cron written directly; the host compiles, checks and describes it.
    @ViewBuilder private var cronFields: some View {
        Picker(L10n.tr("Repeat"), selection: Binding(
            get: { schedule.calendarStyle },
            set: { selectFrequency($0) }
        )) {
            ForEach(Array(RoutineScheduleDraft.repeatChoices.enumerated()), id: \.offset) { _, choice in
                Text(repeatTitle(choice.id)).tag(choice.id)
            }
        }
        .pickerStyle(.menu)

        switch schedule.calendarStyle {
        case "hourly":
            Picker(L10n.tr("Minute"), selection: $schedule.minute) {
                ForEach(0..<60, id: \.self) { minute in
                    Text(String(format: ":%02d", minute)).tag(minute)
                }
            }
            .pickerStyle(.menu)
        case "daily", "weekdays":
            timeRow
        case "weekly":
            Picker(L10n.tr("On"), selection: $schedule.weekday) {
                ForEach([1, 2, 3, 4, 5, 6, 0], id: \.self) { day in
                    Text(weekdayTitle(day)).tag(day)
                }
            }
            .pickerStyle(.menu)
            timeRow
        default:
            EmptyView()
        }

        if schedule.calendarStyle == "custom" {
            TextField(L10n.tr("Cron"), text: $schedule.expression, prompt: Text("0 9 * * 1-5"))
                .font(.body.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        timeZoneRow
    }

    private var timeRow: some View {
        DatePicker(L10n.tr("At"), selection: $schedule.timeOfDay, displayedComponents: .hourAndMinute)
            .environment(\.timeZone, .gmt)
    }

    private var timeZoneRow: some View {
        Picker(L10n.tr("Time zone"), selection: $schedule.zone) {
            ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { zone in
                Text(zone).tag(zone)
            }
        }
        .pickerStyle(.menu)
    }

    /// The schedule section's footer: what the host read, or why it can't; the next run leads.
    @ViewBuilder private var scheduleFooter: some View {
        if let previewError {
            Text(previewError)
                .foregroundStyle(Palette.danger)
                .fixedSize(horizontal: false, vertical: true)
        } else if let preview = (checkedSchedule == schedule ? preview : nil) {
            VStack(alignment: .leading, spacing: 2) {
                if let next = preview.nextRunAt {
                    Text("\(L10n.tr("Next run"))：\(Date(milliseconds: next).formatted(date: .abbreviated, time: .shortened))")
                }
                Text(preview.summary)
                if let warning = preview.warning {
                    Text(warning)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if schedule.calendarStyle == "custom" {
            Text(L10n.tr("minute  hour  day  month  weekday"))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    /// Custom starts from the cron the host compiled for the checked choice it replaces.
    private func selectFrequency(_ style: String) {
        let compiled = checkedSchedule == schedule ? preview?.cronExpression : nil
        withAnimation(Motion.reduced(Motion.layout, reduceMotion)) { schedule = schedule.repeating(style, compiled: compiled) }
    }

    private func triggerTitle(_ id: String, fallback: String) -> String {
        switch id {
        case "cron": return L10n.tr("Schedule")
        case "webhook": return L10n.tr("Webhook")
        default: return fallback
        }
    }

    private func repeatTitle(_ id: String) -> String {
        switch id {
        case "hourly": return L10n.tr("Hourly")
        case "daily": return L10n.tr("Daily")
        case "weekdays": return L10n.tr("Weekdays")
        case "weekly": return L10n.tr("Weekly")
        case "custom": return L10n.tr("Custom")
        default: return id
        }
    }

    private func weekdayTitle(_ weekday: Int) -> String {
        // The host counts 0 = Sunday … 6 = Saturday, like cron.
        switch weekday {
        case 0: return L10n.tr("Sunday")
        case 1: return L10n.tr("Monday")
        case 2: return L10n.tr("Tuesday")
        case 3: return L10n.tr("Wednesday")
        case 4: return L10n.tr("Thursday")
        case 5: return L10n.tr("Friday")
        default: return L10n.tr("Saturday")
        }
    }

    // MARK: - Data

    private func checkSchedule() async {
        let requested = schedule
        preview = nil
        previewError = nil
        checkedSchedule = nil
        do {
            guard let client = model.client else { throw URLError(.notConnectedToInternet) }
            let result = try await client.routineSchedule(draft: requested)
            try Task.checkCancellation()
            guard schedule == requested else { return }
            preview = result
            checkedSchedule = requested
        } catch {
            guard !Task.isCancelled, schedule == requested else { return }
            previewError = error.localizedDescription
        }
    }

    private func loadSchedule() async {
        guard let client = model.client else { error = L10n.tr("Connect to this computer to load the schedule."); return }
        do {
            let result = try await client.routineSchedule(triggers: routine?.triggers ?? [], timeZone: TimeZone.current.identifier)
            schedule = result.draft.forMobileEditor()
            preview = result
            checkedSchedule = result.draft
            loaded = true
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func save() {
        guard let client = model.client, canSave else { return }
        busy = true
        error = nil
        Task {
            defer { busy = false }
            do {
                let result = try await client.saveRoutine(botId: botId, id: routine?.id, name: name,
                    instruction: instruction, schedule: schedule, timeoutSeconds: timeout)
                saved(result)
            } catch { self.error = error.localizedDescription }
        }
    }

    private func deleteRoutine() {
        guard let routine else { return }
        Task {
            do {
                try await model.client?.routineAction("deleteRoutine", botId: botId, id: routine.id)
                saved(nil)
            } catch { self.error = error.localizedDescription }
        }
    }

    private func runNow() {
        guard let routine else { return }
        Task {
            do {
                try await model.client?.routineAction("runRoutine", botId: botId, id: routine.id)
                withAnimation(Motion.reduced(Motion.hover, reduceMotion)) { started = true }
            } catch { self.error = error.localizedDescription }
        }
    }
}

/// A Remix glyph at the settings rows' icon metrics (20pt in a 28pt box).
private struct FormIcon: View {
    let name: String
    init(_ name: String) { self.name = name }

    var body: some View {
        RemixIcon(name, size: 20)
            .frame(width: 28, height: 28)
    }
}
