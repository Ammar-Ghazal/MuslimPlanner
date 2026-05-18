import SwiftUI
import SwiftData

struct TaskEditorSheet: View {
    // Pass nil for new task, an existing PlanTask to edit
    var task: PlanTask?
    let date: Date
    let prayerBlock: String
    let prayerTimes: [PrayerTime]

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var title          = ""
    @State private var hasStartTime   = false
    @State private var startTime      = Date()
    @State private var hasDuration    = false
    @State private var durationMins   = 30
    @State private var selectedBlock  = ""
    @State private var selectedCat: Category?
    @State private var isCompleted    = false

    private var isEditing: Bool { task != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task title", text: $title)
                        .font(.body)
                }

                Section("Time (optional)") {
                    Toggle("Set start time", isOn: $hasStartTime.animation())
                    if hasStartTime {
                        DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                        Toggle("Set duration", isOn: $hasDuration.animation())
                        if hasDuration {
                            Stepper("\(durationMins) min", value: $durationMins, in: 5 ... 480, step: 5)
                        }
                    }
                }

                Section("Prayer block") {
                    Picker("Block", selection: $selectedBlock) {
                        ForEach(prayerTimes) { p in
                            Text(p.name).tag(p.blockName)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    CategoryPicker(selected: $selectedCat)
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

    // MARK: - Populate from existing task

    private func populate() {
        if let t = task {
            title         = t.title
            hasStartTime  = t.startTime != nil
            startTime     = t.startTime ?? Date()
            hasDuration   = t.durationMinutes != nil
            durationMins  = t.durationMinutes ?? 30
            selectedBlock = t.prayerBlock
            selectedCat   = t.category
            isCompleted   = t.isCompleted
        } else {
            selectedBlock = prayerBlock.isEmpty ? (prayerTimes.first?.blockName ?? "Fajr") : prayerBlock
            let cal = Calendar.current
            startTime = cal.date(bySettingHour: cal.component(.hour, from: Date()),
                                 minute: cal.component(.minute, from: Date()),
                                 second: 0, of: date) ?? date
        }
    }

    // MARK: - Save

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        guard !cleanTitle.isEmpty else { return }

        let cal = Calendar.current
        let base = cal.startOfDay(for: date)
        let computedStart: Date? = hasStartTime ? cal.date(
            bySettingHour:   cal.component(.hour,   from: startTime),
            minute:          cal.component(.minute, from: startTime),
            second: 0, of: base
        ) : nil

        if let t = task {
            t.title           = cleanTitle
            t.prayerBlock     = selectedBlock
            t.startTime       = computedStart
            t.durationMinutes = hasDuration ? durationMins : nil
            t.category        = selectedCat
            t.isCompleted     = isCompleted
        } else {
            let newTask = PlanTask(
                title:           cleanTitle,
                date:            base,
                prayerBlock:     selectedBlock,
                startTime:       computedStart,
                durationMinutes: hasDuration ? durationMins : nil,
                category:        selectedCat
            )
            ctx.insert(newTask)
        }
        dismiss()
    }
}
