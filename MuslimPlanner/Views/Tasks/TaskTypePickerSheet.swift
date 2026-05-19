import SwiftUI
import SwiftData

// MARK: - Picker sheet (outer container with NavigationStack)

struct TaskTypePickerSheet: View {
    let date: Date
    let prayerTimes: [PrayerTime]

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskTemplate.name) private var allTemplates: [TaskTemplate]

    private var rootTemplates: [TaskTemplate] {
        allTemplates.filter(\.isRoot)
    }

    var body: some View {
        NavigationStack {
            List {
                // Custom blank task
                Section {
                    NavigationLink {
                        TaskCreatorView(prefill: nil, date: date, prayerTimes: prayerTimes, onDone: { dismiss() })
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.pencil")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            Text("Custom Task").foregroundStyle(.primary)
                        }
                    }
                }

                // Template tree (roots only; drill into subtasks via NavigationLink)
                if !rootTemplates.isEmpty {
                    Section("Task Types") {
                        ForEach(rootTemplates) { template in
                            if template.subtasks.isEmpty {
                                NavigationLink {
                                    TaskCreatorView(prefill: template, date: date, prayerTimes: prayerTimes, onDone: { dismiss() })
                                } label: {
                                    templateRow(template)
                                }
                            } else {
                                NavigationLink {
                                    SubtaskPickerView(parent: template, date: date, prayerTimes: prayerTimes, onDone: { dismiss() })
                                } label: {
                                    templateRow(template)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func templateRow(_ template: TaskTemplate) -> some View {
        HStack(spacing: 10) {
            Image(systemName: template.symbolName)
                .foregroundStyle(Color(hex: template.colorHex))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name).foregroundStyle(.primary)
                if !template.subtasks.isEmpty {
                    Text("\(template.subtasks.count) subtask\(template.subtasks.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(template.durationMinutes)m")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Subtask picker (pushed when parent has subtasks)

private struct SubtaskPickerView: View {
    let parent: TaskTemplate
    let date: Date
    let prayerTimes: [PrayerTime]
    let onDone: () -> Void

    var body: some View {
        List {
            // Children first
            Section {
                ForEach(parent.sortedSubtasks) { sub in
                    NavigationLink {
                        TaskCreatorView(prefill: sub, date: date, prayerTimes: prayerTimes, onDone: onDone)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: sub.symbolName)
                                .foregroundStyle(Color(hex: sub.colorHex))
                                .frame(width: 24)
                            Text(sub.name).foregroundStyle(.primary)
                            Spacer()
                            Text("\(sub.durationMinutes)m")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Option to use the parent itself without picking a subtask
            Section {
                NavigationLink {
                    TaskCreatorView(prefill: parent, date: date, prayerTimes: prayerTimes, onDone: onDone)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: parent.symbolName)
                            .foregroundStyle(Color(hex: parent.colorHex).opacity(0.5))
                            .frame(width: 24)
                        Text("No subtask – just \(parent.name)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(parent.durationMinutes)m")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(parent.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Task creator (inline editor, pushed as a navigation destination)
// Does not wrap itself in a NavigationStack — inherits the picker's stack.

private struct TaskCreatorView: View {
    let prefill: TaskTemplate?
    let date: Date
    let prayerTimes: [PrayerTime]
    let onDone: () -> Void

    @Environment(\.modelContext) private var ctx

    @State private var title = ""
    @State private var startTime = Date()
    @State private var durationMins = 30
    @State private var linkedTemplate: TaskTemplate? = nil

    var body: some View {
        Form {
            Section {
                TextField("Task title", text: $title)
            }

            Section("Schedule") {
                DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                Stepper("Duration: \(durationMins) min", value: $durationMins, in: 5...480, step: 5)
                let end = startTime.addingTimeInterval(Double(durationMins * 60))
                LabeledContent("Ends at", value: end.formatted(.dateTime.hour().minute()))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("New Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear { populate() }
    }

    private func populate() {
        startTime = defaultStartTime()
        guard let p = prefill else { return }
        title = p.displayTitle
        durationMins = p.durationMinutes
        linkedTemplate = p
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

        let task = PlanTask(
            title: cleanTitle,
            date: base,
            prayerBlock: prayerBlock(for: computedStart),
            startTime: computedStart,
            durationMinutes: durationMins
        )
        task.taskType = linkedTemplate
        ctx.insert(task)
        try? ctx.save()
        onDone()
    }
}
