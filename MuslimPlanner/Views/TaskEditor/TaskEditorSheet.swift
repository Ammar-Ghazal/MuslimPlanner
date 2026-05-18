import SwiftUI
import SwiftData

struct TaskEditorSheet: View {
    var task: PlanTask?
    let date: Date
    let prayerTimes: [PrayerTime]

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var title        = ""
    @State private var startTime    = Date()
    @State private var durationMins = 30
    @State private var selectedCat: Category?
    @State private var isCompleted  = false

    private var isEditing: Bool { task != nil }

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

    private func populate() {
        if let t = task {
            title        = t.title
            startTime    = t.startTime ?? defaultStartTime()
            durationMins = t.durationMinutes ?? 30
            selectedCat  = t.category
            isCompleted  = t.isCompleted
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
            t.category        = selectedCat
            t.isCompleted     = isCompleted
        } else {
            ctx.insert(PlanTask(
                title:           cleanTitle,
                date:            base,
                prayerBlock:     block,
                startTime:       computedStart,
                durationMinutes: durationMins,
                category:        selectedCat
            ))
        }
        dismiss()
    }
}
