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

    @State private var title           = ""
    @State private var startTime       = Date()
    @State private var durationMins    = 30
    @State private var isCompleted     = false
    @State private var linkedTemplate: TaskTemplate? = nil
    @State private var checklistItems: [String] = []
    @State private var completedItems: Set<String> = []
    @State private var newItemText     = ""

    private var isEditing: Bool { task != nil }
    private var isLinkedToType: Bool { linkedTemplate != nil }
    private var isPrayer: Bool { task?.prayerBlock != nil && linkedTemplate == nil }

    var body: some View {
        NavigationStack {
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

                if !isPrayer {
                    Section {
                        if isLinkedToType {
                            Label("Saved as \"\(linkedTemplate!.name)\"", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button {
                                saveAsTaskType()
                            } label: {
                                Label("Save as Task Type", systemImage: "bookmark")
                            }
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    Section {
                        ForEach(checklistItems, id: \.self) { item in
                            HStack(spacing: 12) {
                                Image(systemName: completedItems.contains(item) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(completedItems.contains(item) ? .green : .secondary)
                                Text(item)
                                    .strikethrough(completedItems.contains(item))
                                    .foregroundStyle(completedItems.contains(item) ? .secondary : .primary)
                                Spacer()
                                Button(role: .destructive) {
                                    checklistItems.removeAll { $0 == item }
                                    completedItems.remove(item)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .font(.system(size: 16))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if completedItems.contains(item) {
                                    completedItems.remove(item)
                                } else {
                                    completedItems.insert(item)
                                }
                            }
                        }
                        HStack {
                            TextField("Add checklist item", text: $newItemText)
                            Button(action: addChecklistItem) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                            .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } header: {
                        Text("Checklist")
                    }
                }

                if isEditing {
                    Section {
                        Toggle("Completed", isOn: $isCompleted)
                    }
                    Section {
                        Button("Delete Task", role: .destructive) {
                            if let t = task { ctx.delete(t) }
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
        }
    }

    private func addChecklistItem() {
        let item = newItemText.trimmingCharacters(in: .whitespaces)
        guard !item.isEmpty else { return }
        checklistItems.append(item)
        newItemText = ""
    }

    private func populate() {
        if let t = task {
            title           = t.title
            startTime       = t.startTime ?? defaultStartTime()
            durationMins    = t.durationMinutes ?? 30
            isCompleted     = t.isCompleted
            linkedTemplate  = t.taskType
            checklistItems  = t.checklistItems
            completedItems  = Set(t.completedItemNames)
        } else if let p = prefill {
            title           = p.path
            durationMins    = p.durationMinutes
            startTime       = defaultStartTime()
            linkedTemplate  = p
        } else {
            startTime = defaultStartTime()
        }
    }

    private func defaultStartTime() -> Date {
        let cal = Calendar.current
        let now = Date()
        return cal.date(
            bySettingHour:   cal.component(.hour,   from: now),
            minute:          cal.component(.minute, from: now),
            second: 0,
            of: date
        ) ?? date
    }

    private func saveAsTaskType() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else { return }
        let template = TaskTemplate(name: cleanTitle, durationMinutes: durationMins)
        ctx.insert(template)
        linkedTemplate = template
        task?.taskType = template
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
            bySettingHour:   cal.component(.hour,   from: startTime),
            minute:          cal.component(.minute, from: startTime),
            second: 0,
            of: base
        ) ?? base

        let block = prayerBlock(for: computedStart)

        if let t = task {
            t.title           = cleanTitle
            t.startTime       = computedStart
            t.durationMinutes = durationMins
            t.prayerBlock     = block
            t.isCompleted     = isCompleted
            t.taskType        = linkedTemplate
            t.checklistItems  = checklistItems
            t.completedItemNames = Array(completedItems).sorted()
        } else {
            let newTask = PlanTask(
                title:           cleanTitle,
                date:            base,
                prayerBlock:     block,
                startTime:       computedStart,
                durationMinutes: durationMins
            )
            newTask.taskType = linkedTemplate
            newTask.checklistItems = checklistItems
            newTask.completedItemNames = Array(completedItems).sorted()
            ctx.insert(newTask)
        }
        onSave?()
        dismiss()
    }
}
