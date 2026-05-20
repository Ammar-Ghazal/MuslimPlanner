import SwiftUI
import SwiftData

struct TaskEditorSheet: View {
    var task: PlanTask?
    var prefill: TaskTemplate? = nil
    var onSave: (() -> Void)? = nil
    let date: Date
    let prayerTimes: [PrayerTime]

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var startTime = Date()
    @State private var durationMins = 30
    @State private var isCompleted = false
    @State private var linkedTemplate: TaskTemplate? = nil
    @State private var showTypePicker = false

    private var isEditing: Bool { task != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task title", text: $title)
                }

                Section("Start Time") {
                    DatePicker("Time", selection: $startTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }

                Section("Duration") {
                    Picker("Duration", selection: $durationMins) {
                        ForEach(Array(stride(from: 5, through: 480, by: 5)), id: \.self) { mins in
                            Text(formatDuration(mins)).tag(mins)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 110)
                    .clipped()

                    let end = startTime.addingTimeInterval(Double(durationMins * 60))
                    LabeledContent("Ends at", value: end.formatted(.dateTime.hour().minute()))
                        .foregroundStyle(.secondary)
                }

                // Task type — shows current type and lets the user change it
                Section("Task Type") {
                    if let t = linkedTemplate {
                        Button { showTypePicker = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: t.symbolName)
                                    .foregroundStyle(Color(hex: t.colorHex))
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.displayTitle).foregroundStyle(.primary)
                                    if t.parent != nil {
                                        Text(t.path).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    } else {
                        Button { showTypePicker = true } label: {
                            Label("Set Task Type", systemImage: "tag")
                                .foregroundStyle(.blue)
                        }
                    }
                }

                if isEditing {
                    Section {
                        Toggle("Completed", isOn: $isCompleted)
                    }
                    Section {
                        Button("Delete Task", role: .destructive) {
                            if let t = task { ctx.delete(t); try? ctx.save() }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { populate() }
            // Type picker: a simple flat list of all templates (sheet-within-sheet is fine here
            // since it's just a list — no further navigation required)
            .sheet(isPresented: $showTypePicker) {
                TemplateTreePickerSheet(constrainedTo: linkedTemplate.map(\.root)) { chosen in
                    linkedTemplate = chosen
                    title = chosen.displayTitle
                    showTypePicker = false
                }
            }
        }
    }

    // MARK: - Helpers

    private func populate() {
        if let t = task {
            title = t.title
            startTime = t.startTime ?? defaultStartTime()
            durationMins = t.durationMinutes ?? 30
            isCompleted = t.isCompleted
            linkedTemplate = t.taskType
        } else if let p = prefill {
            title = p.displayTitle
            durationMins = p.durationMinutes
            linkedTemplate = p
            startTime = defaultStartTime()
        } else {
            startTime = defaultStartTime()
        }
    }

    private func defaultStartTime() -> Date {
        let cal = Calendar.current
        let now = Date()
        return cal.date(
            bySettingHour: cal.component(.hour, from: now),
            minute: cal.component(.minute, from: now),
            second: 0, of: date
        ) ?? date
    }

    private func formatDuration(_ mins: Int) -> String {
        if mins < 60 { return "\(mins) min" }
        if mins % 60 == 0 { return "\(mins / 60) hr" }
        return "\(mins / 60) hr \(mins % 60) min"
    }

    private func prayerBlock(for time: Date) -> String {
        for (i, prayer) in prayerTimes.enumerated() {
            let next = i + 1 < prayerTimes.count ? prayerTimes[i + 1].time : Date.distantFuture
            if time >= prayer.time && time < next { return prayer.blockName }
        }
        return prayerTimes.first?.blockName ?? "Fajr"
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else { return }

        let cal = Calendar.current
        let base = cal.startOfDay(for: date)
        let computedStart = cal.date(
            bySettingHour: cal.component(.hour, from: startTime),
            minute: cal.component(.minute, from: startTime),
            second: 0, of: base
        ) ?? base

        let block = prayerBlock(for: computedStart)

        if let t = task {
            t.title = cleanTitle
            t.startTime = computedStart
            t.durationMinutes = durationMins
            t.prayerBlock = block
            t.isCompleted = isCompleted
            t.taskType = linkedTemplate
        } else {
            let newTask = PlanTask(
                title: cleanTitle,
                date: base,
                prayerBlock: block,
                startTime: computedStart,
                durationMinutes: durationMins
            )
            newTask.taskType = linkedTemplate
            ctx.insert(newTask)
        }
        try? ctx.save()
        onSave?()
        dismiss()
    }
}

// MARK: - Template tree picker (for "Change Type" inside the editor)
// Shows the full template tree with NavigationLink drill-down.
// Lives here so it can call back into TaskEditorSheet without circular deps.

private struct TemplateTreePickerSheet: View {
    /// When set, the picker is scoped to this root's subtree only.
    /// When nil (task has no type yet), all root templates are shown.
    let constrainedTo: TaskTemplate?
    let onPick: (TaskTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskTemplate.name) private var allTemplates: [TaskTemplate]

    private var rootTemplates: [TaskTemplate] { allTemplates.filter(\.isRoot) }

    var body: some View {
        NavigationStack {
            List {
                if let root = constrainedTo {
                    // Scoped view: only show this root's subtree
                    if root.subtasks.isEmpty {
                        // Root has no subtasks — nothing to change to
                        ContentUnavailableView(
                            "No Subtypes",
                            systemImage: "square.stack",
                            description: Text("\(root.name) has no subtypes defined.")
                        )
                    } else {
                        Section {
                            ForEach(root.sortedSubtasks) { sub in
                                Button { onPick(sub); dismiss() } label: { templateRow(sub) }
                            }
                        }
                        Section {
                            Button { onPick(root); dismiss() } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: root.symbolName)
                                        .foregroundStyle(Color(hex: root.colorHex).opacity(0.5))
                                        .frame(width: 24)
                                    Text("No subtype – just \(root.name)").foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(root.durationMinutes)m").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    // Unconstrained: show all roots (task has no type yet)
                    if rootTemplates.isEmpty {
                        ContentUnavailableView(
                            "No Task Types",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Add task types in Settings → Task Types.")
                        )
                    } else {
                        ForEach(rootTemplates) { template in
                            if template.subtasks.isEmpty {
                                Button { onPick(template); dismiss() } label: { templateRow(template) }
                            } else {
                                NavigationLink {
                                    subtaskPicker(for: template)
                                } label: {
                                    templateRow(template)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(constrainedTo.map { "Change \($0.name)" } ?? "Select Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func subtaskPicker(for parent: TaskTemplate) -> some View {
        List {
            Section {
                ForEach(parent.sortedSubtasks) { sub in
                    Button { onPick(sub); dismiss() } label: { templateRow(sub) }
                }
            }
            Section {
                Button { onPick(parent); dismiss() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: parent.symbolName)
                            .foregroundStyle(Color(hex: parent.colorHex).opacity(0.5))
                            .frame(width: 24)
                        Text("No subtype – just \(parent.name)").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(parent.durationMinutes)m").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(parent.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func templateRow(_ template: TaskTemplate) -> some View {
        HStack(spacing: 10) {
            Image(systemName: template.symbolName)
                .foregroundStyle(Color(hex: template.colorHex))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.displayTitle).foregroundStyle(.primary)
                if template.parent != nil {
                    Text(template.path).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(template.durationMinutes)m").font(.caption).foregroundStyle(.secondary)
        }
    }
}
