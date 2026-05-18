import SwiftUI
import SwiftData

struct TaskTemplateEditorSheet: View {
    var template: TaskTemplate?

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskTemplate.name) private var allTemplates: [TaskTemplate]

    @State private var name         = ""
    @State private var durationMins = 30
    @State private var selectedCat: Category?
    @State private var subtasks: [TaskTemplate] = []
    @State private var showSubtaskPicker = false

    private var isEditing: Bool { template != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task type name", text: $name)
                }

                Section("Default duration") {
                    Stepper("\(durationMins) min", value: $durationMins, in: 5...480, step: 5)
                }

                Section {
                    CategoryPicker(selected: $selectedCat)
                }

                Section {
                    ForEach(subtasks) { sub in
                        HStack {
                            Text(sub.name)
                            Spacer()
                            Text("\(sub.durationMinutes)m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { subtasks.remove(atOffsets: $0) }
                    .onMove  { subtasks.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        showSubtaskPicker = true
                    } label: {
                        Label("Add Subtask", systemImage: "plus")
                    }
                    .disabled(availableSubtasks.isEmpty)
                } header: {
                    Text("Subtasks")
                } footer: {
                    if !subtasks.isEmpty {
                        Text("Total: \(subtasks.reduce(durationMins) { $0 + $1.durationMinutes })m")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Task Type" : "New Task Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !subtasks.isEmpty { EditButton() }
                }
            }
            .onAppear { populate() }
            .sheet(isPresented: $showSubtaskPicker) {
                SubtaskPickerSheet(templates: availableSubtasks) { subtasks.append($0) }
            }
        }
    }

    // Templates eligible to be added as subtasks:
    // not self, not already in the list, not already a subtask of this template
    private var availableSubtasks: [TaskTemplate] {
        allTemplates.filter { t in
            t.persistentModelID != template?.persistentModelID &&
            !subtasks.contains(where: { $0.persistentModelID == t.persistentModelID })
        }
    }

    private func populate() {
        guard let t = template else { return }
        name         = t.name
        durationMins = t.durationMinutes
        selectedCat  = t.category
        subtasks     = t.sortedSubtasks
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { return }

        if let t = template {
            t.name            = cleanName
            t.durationMinutes = durationMins
            t.category        = selectedCat
            applySubtasks(to: t)
        } else {
            let t = TaskTemplate(name: cleanName, durationMinutes: durationMins)
            t.category = selectedCat
            ctx.insert(t)
            applySubtasks(to: t)
        }
        dismiss()
    }

    // Update subtasks array and sort order. SwiftData auto-manages parent inverse.
    private func applySubtasks(to parent: TaskTemplate) {
        for (i, sub) in subtasks.enumerated() {
            sub.sortOrder = i
        }
        parent.subtasks = subtasks
    }
}

// MARK: - Subtask picker

private struct SubtaskPickerSheet: View {
    let templates: [TaskTemplate]
    let onPick: (TaskTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    var body: some View {
        NavigationStack {
            List {
                // ── Create a brand-new subtask inline ──
                Section {
                    NavigationLink {
                        NewSubtaskForm { newTemplate in
                            ctx.insert(newTemplate)
                            onPick(newTemplate)
                            dismiss()
                        }
                    } label: {
                        Label("New Subtask…", systemImage: "plus")
                    }
                }

                // ── Pick from existing task types ──
                if !templates.isEmpty {
                    Section("Existing Task Types") {
                        ForEach(templates) { t in
                            Button {
                                onPick(t)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(t.name).foregroundStyle(.primary)
                                        if !t.subtasks.isEmpty {
                                            Text("\(t.subtasks.count) subtask\(t.subtasks.count == 1 ? "" : "s")")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("\(t.durationMinutes)m")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Inline new-subtask form

private struct NewSubtaskForm: View {
    let onSave: (TaskTemplate) -> Void

    @State private var name         = ""
    @State private var durationMins = 30
    @State private var selectedCat: Category?

    var body: some View {
        Form {
            Section {
                TextField("Subtask name", text: $name)
            }
            Section("Duration") {
                Stepper("\(durationMins) min", value: $durationMins, in: 5...480, step: 5)
            }
            Section {
                CategoryPicker(selected: $selectedCat)
            }
        }
        .navigationTitle("New Subtask")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let t = TaskTemplate(name: name.trimmingCharacters(in: .whitespaces),
                                        durationMinutes: durationMins)
                    t.category = selectedCat
                    onSave(t)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
