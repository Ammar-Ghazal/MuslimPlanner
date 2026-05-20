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

    private enum ActiveSheet: Identifiable {
        case subtaskPicker, colorPicker
        var id: Self { self }
    }
    @State private var activeSheet: ActiveSheet?

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
                        Button(action: { activeSheet = .colorPicker }) {
                            Circle().fill(Color(hex: colorHex)).frame(width: 32, height: 32)
                        }
                    }
                    NavigationLink {
                        IconListView(selectedIcon: $symbolName, colorHex: colorHex)
                    } label: {
                        HStack {
                            Text("Icon")
                            Spacer()
                            Image(systemName: symbolName)
                                .font(.system(size: 20))
                                .foregroundStyle(Color(hex: colorHex))
                        }
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
                        activeSheet = .subtaskPicker
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
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .subtaskPicker:
                SubtaskPickerSheet(templates: availableSubtasks) { subtasks.append($0) }
            case .colorPicker:
                ColorPickerSheet(selectedColor: $colorHex)
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

// MARK: - Icon list (NavigationLink destination)

private struct IconListView: View {
    @Binding var selectedIcon: String
    let colorHex: String
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private let categories: [(name: String, icons: [String])] = [
        ("General", [
            "circle.fill", "square.fill", "star.fill", "heart.fill",
            "bookmark.fill", "flag.fill", "tag.fill", "bell.fill",
            "checkmark.circle.fill", "exclamationmark.circle.fill",
            "info.circle.fill", "questionmark.circle.fill"
        ]),
        ("Time & Planning", [
            "clock.fill", "calendar", "alarm.fill", "hourglass",
            "timer", "chart.bar.fill", "list.bullet", "checklist",
            "tray.fill", "archivebox.fill", "note.text", "arrow.clockwise"
        ]),
        ("Work & Study", [
            "briefcase.fill", "book.fill", "pencil", "pencil.circle.fill",
            "doc.fill", "folder.fill", "graduationcap.fill", "lightbulb.fill",
            "brain", "magnifyingglass", "wrench.fill", "hammer.fill"
        ]),
        ("Prayer & Wellness", [
            "hands.sparkles.fill", "figure.stand", "moon.fill", "sun.max.fill",
            "sparkles", "drop.fill", "leaf.fill", "wind",
            "figure.mind.and.body", "cross.case.fill", "lungs.fill"
        ]),
        ("Health & Fitness", [
            "dumbbell.fill", "figure.walk", "figure.run",
            "heart.fill", "pills.fill", "bed.double.fill", "shower.fill",
            "bicycle", "sportscourt.fill", "trophy.fill"
        ]),
        ("Food & Home", [
            "fork.knife", "cup.and.saucer.fill", "carrot.fill",
            "house.fill", "building.fill", "cart.fill", "bag.fill",
            "trash", "sofa.fill"
        ]),
        ("People & Social", [
            "person.fill", "person.2.fill", "phone.fill", "message.fill",
            "envelope.fill", "video.fill", "bubble.left.fill",
            "hand.wave.fill", "gift.fill"
        ]),
        ("Entertainment", [
            "music.note", "film.fill", "gamecontroller.fill", "tv.fill",
            "headphones", "mic.fill", "photo.fill", "camera.fill",
            "paintbrush.fill", "book.closed.fill", "theatermasks.fill"
        ]),
        ("Transport & Travel", [
            "car.fill", "airplane", "tram.fill", "bus.fill",
            "ferry.fill", "map.fill", "location.fill", "globe"
        ]),
        ("Finance", [
            "dollarsign.circle.fill", "banknote.fill", "creditcard.fill",
            "chart.line.uptrend.xyaxis", "chart.pie.fill", "percent"
        ])
    ]

    private var visibleCategories: [(name: String, icons: [String])] {
        guard !searchText.isEmpty else { return categories }
        let query = searchText.lowercased()
        return categories.compactMap { cat in
            if cat.name.lowercased().contains(query) { return cat }
            let hits = cat.icons.filter {
                $0.replacingOccurrences(of: ".", with: " ")
                  .replacingOccurrences(of: "fill", with: "")
                  .contains(query)
            }
            return hits.isEmpty ? nil : (name: cat.name, icons: hits)
        }
    }

    var body: some View {
        List {
            if visibleCategories.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(visibleCategories, id: \.name) { category in
                    Section(category.name) {
                        ForEach(category.icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: icon)
                                        .font(.system(size: 20))
                                        .foregroundStyle(selectedIcon == icon ? Color(hex: colorHex) : .primary)
                                        .frame(width: 28)
                                    Text(iconLabel(icon))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedIcon == icon {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color(hex: colorHex))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Choose Icon")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search icons")
    }

    private func iconLabel(_ symbol: String) -> String {
        symbol
            .replacingOccurrences(of: ".fill", with: "")
            .replacingOccurrences(of: ".", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

// MARK: - Color picker

struct ColorPickerSheet: View {
    @Binding var selectedColor: String
    @Environment(\.dismiss) private var dismiss

    @State private var customColor: Color = .blue

    private let presets = [
        ("FF3B30", "Red"),    ("FF9500", "Orange"), ("FFCC00", "Yellow"),
        ("34C759", "Green"),  ("00C7BE", "Teal"),   ("00B4D8", "Cyan"),
        ("0A84FF", "Blue"),   ("5856D6", "Purple"), ("AF52DE", "Pink"),
        ("FF2D55", "Rose"),   ("A2845E", "Brown"),  ("8E7CC3", "Lavender"),
        ("007AFF", "Royal Blue"), ("5AC8FA", "Sky Blue"), ("50E3C2", "Mint")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Custom") {
                    ColorPicker("Color wheel", selection: $customColor, supportsOpacity: false)
                        .onChange(of: customColor) { _, newColor in
                            selectedColor = newColor.toHex()
                        }
                }

                Section("Presets") {
                    ForEach(presets, id: \.0) { hex, name in
                        HStack {
                            Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                            Text(name)
                            Spacer()
                            if selectedColor.uppercased() == hex {
                                Image(systemName: "checkmark").foregroundStyle(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedColor = hex
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
            .onAppear { customColor = Color(hex: selectedColor) }
        }
    }
}

