import SwiftUI
import SwiftData

struct TaskTemplateEditorSheet: View {
    var template: TaskTemplate?

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskTemplate.name) private var allTemplates: [TaskTemplate]

    @State private var name         = ""
    @State private var durationMins = 30
    @State private var colorHex     = "007AFF"
    @State private var symbolName   = "circle.fill"
    @State private var subtasks: [TaskTemplate] = []
    @State private var showSubtaskPicker = false
    @State private var showColorPicker = false
    @State private var showIconPicker = false

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

                Section("Appearance") {
                    HStack {
                        Text("Color")
                        Spacer()
                        Button(action: { showColorPicker = true }) {
                            Circle().fill(Color(hex: colorHex)).frame(width: 32, height: 32)
                        }
                    }
                    .sheet(isPresented: $showColorPicker) {
                        ColorPickerSheet(selectedColor: $colorHex, dismiss: $showColorPicker)
                    }
                    HStack {
                        Text("Icon")
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: symbolName).font(.system(size: 20))
                            Button(action: { showIconPicker = true }) {
                                Text("Change").font(.caption)
                            }
                        }
                    }
                    .sheet(isPresented: $showIconPicker) {
                        IconPickerSheet(selectedIcon: $symbolName, dismiss: $showIconPicker)
                    }
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
        colorHex     = t.colorHex
        symbolName   = t.symbolName
        subtasks     = t.sortedSubtasks
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { return }

        if let t = template {
            t.name            = cleanName
            t.durationMinutes = durationMins
            t.colorHex        = colorHex
            t.symbolName      = symbolName
            applySubtasks(to: t)
        } else {
            let t = TaskTemplate(name: cleanName, durationMinutes: durationMins, colorHex: colorHex, symbolName: symbolName)
            ctx.insert(t)
            applySubtasks(to: t)
        }
        try? ctx.save()
        dismiss()
    }

    private func applySubtasks(to parent: TaskTemplate) {
        // Clear parent on any subtasks that were removed from the list
        let keepIDs = Set(subtasks.map { $0.persistentModelID })
        for sub in parent.subtasks where !keepIDs.contains(sub.persistentModelID) {
            sub.parent = nil
        }
        // Set parent and order on every subtask in the new list
        for (i, sub) in subtasks.enumerated() {
            sub.parent = parent
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

    var body: some View {
        Form {
            Section {
                TextField("Subtask name", text: $name)
            }
            Section("Duration") {
                Stepper("\(durationMins) min", value: $durationMins, in: 5...480, step: 5)
            }
        }
        .navigationTitle("New Subtask")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let t = TaskTemplate(name: name.trimmingCharacters(in: .whitespaces),
                                        durationMinutes: durationMins)
                    onSave(t)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// MARK: - Icon picker

private struct IconPickerSheet: View {
    @Binding var selectedIcon: String
    @Binding var dismiss: Bool

    let commonIcons = [
        "circle.fill", "square.fill", "star.fill", "heart.fill",
        "bookmark.fill", "flag.fill", "bell.fill", "clock.fill",
        "checkmark.circle.fill", "pencil.circle.fill", "trash.circle.fill",
        "book.fill", "briefcase.fill", "fork.knife", "dumbbell.fill",
        "person.fill", "building.fill", "car.fill", "airplane",
        "music.note", "film.fill", "gamecontroller.fill", "palette.fill"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 16) {
                    ForEach(commonIcons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            self.dismiss = false
                        }) {
                            VStack {
                                Image(systemName: icon)
                                    .font(.system(size: 28))
                                    .foregroundStyle(selectedIcon == icon ? .green : .primary)
                            }
                            .frame(height: 50)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Color picker

private struct ColorPickerSheet: View {
    @Binding var selectedColor: String
    @Binding var dismiss: Bool

    let colors = [
        "FF3B30", "FF9500", "FFCC00", "34C759", "00C7BE",
        "00B4D8", "0A84FF", "5856D6", "AF52DE", "FF2D55",
        "A2845E", "8E7CC3", "007AFF", "5AC8FA", "50E3C2"
    ]
    let colorNames = [
        "Red", "Orange", "Yellow", "Green", "Teal",
        "Cyan", "Blue", "Purple", "Pink", "Rose",
        "Brown", "Lavender", "Royal Blue", "Sky Blue", "Mint"
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(colors.enumerated()), id: \.offset) { idx, color in
                    HStack {
                        Circle().fill(Color(hex: color)).frame(width: 30, height: 30)
                        Text(colorNames[idx])
                        Spacer()
                        if selectedColor == color {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedColor = color
                        dismiss = false
                    }
                }
            }
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

