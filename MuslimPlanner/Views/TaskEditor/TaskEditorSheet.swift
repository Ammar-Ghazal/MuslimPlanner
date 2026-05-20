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
    @State private var linkedTemplate: TaskTemplate? = nil
    @State private var showTypePicker = false

    // Edit-mode appearance (written back to the task's type on save)
    @State private var symbolName = "circle.fill"
    @State private var colorHex = "007AFF"
    @State private var showIconPicker = false
    @State private var showColorPicker = false

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

                if isEditing {
                    if task?.taskType != nil {
                        Section("Appearance") {
                            Button { showIconPicker = true } label: {
                                HStack {
                                    Text("Icon").foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: symbolName)
                                        .foregroundStyle(Color(hex: colorHex))
                                    Image(systemName: "chevron.right")
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            Button { showColorPicker = true } label: {
                                HStack {
                                    Text("Color").foregroundStyle(.primary)
                                    Spacer()
                                    Circle().fill(Color(hex: colorHex)).frame(width: 22, height: 22)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    Section {
                        Button("Delete Task", role: .destructive) {
                            if let t = task { ctx.delete(t); try? ctx.save() }
                            dismiss()
                        }
                    }
                } else {
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
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { populate() }
            .sheet(isPresented: $showIconPicker) {
                IconPickerSheet(selectedIcon: $symbolName)
            }
            .sheet(isPresented: $showColorPicker) {
                ColorPickerSheet(selectedColor: $colorHex)
            }
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
            symbolName = t.taskType?.symbolName ?? "circle.fill"
            colorHex = t.taskType?.colorHex ?? "007AFF"
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

        if let t = task {
            t.title = cleanTitle
            t.startTime = computedStart
            t.durationMinutes = durationMins
            t.prayerBlock = prayerBlock(for: computedStart)
            t.taskType?.symbolName = symbolName
            t.taskType?.colorHex = colorHex
        } else {
            let newTask = PlanTask(
                title: cleanTitle,
                date: base,
                prayerBlock: prayerBlock(for: computedStart),
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

// MARK: - Template tree picker (for "Change Type" inside the new-task editor)

private struct TemplateTreePickerSheet: View {
    let constrainedTo: TaskTemplate?
    let onPick: (TaskTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskTemplate.name) private var allTemplates: [TaskTemplate]

    private var rootTemplates: [TaskTemplate] { allTemplates.filter(\.isRoot) }

    var body: some View {
        NavigationStack {
            List {
                if let root = constrainedTo {
                    if root.subtasks.isEmpty {
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
