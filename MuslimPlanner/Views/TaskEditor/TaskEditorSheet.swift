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

    @State private var colorHex = "007AFF"
    @State private var iconName = "circle.fill"
    @State private var hasPopulated = false

    private enum ActiveSheet: Identifiable {
        case colorPicker, typePicker
        var id: Self { self }
    }
    @State private var activeSheet: ActiveSheet?

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
                            Button { activeSheet = .colorPicker } label: {
                                HStack {
                                    Text("Color").foregroundStyle(.primary)
                                    Spacer()
                                    Circle().fill(Color(hex: colorHex)).frame(width: 22, height: 22)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            NavigationLink {
                                IconPickerSheet(selectedIcon: $iconName, colorHex: colorHex)
                            } label: {
                                HStack {
                                    Text("Icon").foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: iconName)
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color(hex: colorHex))
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
                            Button { activeSheet = .typePicker } label: {
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
                            Button { activeSheet = .typePicker } label: {
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
            .onAppear {
                guard !hasPopulated else { return }
                hasPopulated = true
                populate()
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .colorPicker:
                ColorPickerSheet(selectedColor: $colorHex)
            case .typePicker:
                TemplateTreePickerSheet(constrainedTo: linkedTemplate.map(\.root)) { chosen in
                    linkedTemplate = chosen
                    title = chosen.displayTitle
                    activeSheet = nil
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
            colorHex = t.taskType?.colorHex ?? "007AFF"
            iconName = t.customIconName ?? t.taskType?.symbolName ?? "circle.fill"
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
            t.taskType?.colorHex = colorHex
            t.customIconName = iconName != (t.taskType?.symbolName ?? "circle.fill") ? iconName : nil
        } else {
            let newTask = PlanTask(
                title: cleanTitle,
                date: base,
                prayerBlock: prayerBlock(for: computedStart),
                startTime: computedStart,
                durationMinutes: durationMins
            )
            newTask.taskType = linkedTemplate
            newTask.customIconName = iconName != (linkedTemplate?.symbolName ?? "circle.fill") ? iconName : nil
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

// MARK: - Icon picker sheet

private struct IconPickerSheet: View {
    @Binding var selectedIcon: String
    let colorHex: String
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private let categories: [(name: String, icons: [String])] = [
        ("General", [
            "circle.fill", "square.fill", "rectangle.fill", "star.fill", "heart.fill",
            "bookmark.fill", "flag.fill", "tag.fill", "bell.fill", "leaf.fill",
            "checkmark.circle.fill", "exclamationmark.circle.fill",
            "info.circle.fill", "questionmark.circle.fill", "xmark.circle.fill",
            "plus.circle.fill", "minus.circle.fill", "diamond.fill", "hexagon.fill",
            "triangle.fill", "seal.fill", "shield.fill", "lock.fill", "key.fill",
            "pin.fill", "paperclip", "link", "bolt.fill", "bell.badge.fill"
        ]),
        ("Time & Planning", [
            "clock.fill", "calendar", "calendar.badge.plus", "alarm.fill", "hourglass",
            "hourglass.bottomhalf.filled", "timer", "stopwatch.fill", "chart.bar.fill",
            "list.bullet", "checklist", "tray.fill", "archivebox.fill", "note.text",
            "arrow.clockwise", "arrow.counterclockwise", "calendar.badge.clock",
            "clock.badge", "calendar.circle.fill", "clock.circle.fill",
            "target", "repeat", "chart.xyaxis.line"
        ]),
        ("Work & Study", [
            "briefcase.fill", "briefcase.circle.fill", "book.fill", "books.vertical.fill",
            "pencil", "pencil.circle.fill", "doc.fill", "doc.badge.ellipsis",
            "folder.fill", "folder.badge.plus", "graduationcap.fill", "lightbulb.fill",
            "lightbulb.circle.fill", "brain", "magnifyingglass", "wrench.fill",
            "hammer.fill", "gearshape.fill", "hammer.circle.fill", "screwdriver.fill",
            "keyboard.fill", "ruler.fill", "newspaper.fill", "clipboard.fill",
            "chart.bar.doc.horizontal.fill", "terminal.fill"
        ]),
        ("Prayer & Wellness", [
            "hands.sparkles.fill", "hand.raised.fill", "figure.stand", "moon.fill",
            "sun.max.fill", "sun.max.circle.fill", "sparkles", "drop.fill",
            "wind", "figure.mind.and.body", "cross.case.fill", "lungs.fill",
            "rosette", "building.columns.fill", "book.closed.fill",
            "mappin.circle.fill", "globe.americas.fill"
        ]),
        ("Health & Fitness", [
            "dumbbell.fill", "figure.walk", "figure.walk.circle.fill", "figure.run",
            "figure.run.circle.fill", "heart.circle.fill", "pills.fill",
            "bed.double.fill", "shower.fill", "bicycle", "bicycle.circle.fill",
            "sportscourt.fill", "trophy.fill", "medal.fill",
            "figure.strengthtraining.traditional", "figure.yoga", "stethoscope",
            "bandage.fill", "cross.circle.fill", "scalemass.fill"
        ]),
        ("Food & Home", [
            "fork.knife", "cup.and.saucer.fill", "carrot.fill",
            "house.fill", "house.circle.fill", "building.fill", "building.2.fill",
            "cart.fill", "cart.circle.fill", "bag.fill", "basket.fill",
            "trash", "trash.circle.fill", "sofa.fill", "refrigerator.fill",
            "microwave.fill", "flame.fill", "wineglass.fill", "birthday.cake.fill",
            "popcorn.fill", "oven.fill"
        ]),
        ("People & Social", [
            "person.fill", "person.circle.fill", "person.2.fill", "person.2.circle.fill",
            "person.3.fill", "phone.fill", "phone.circle.fill", "message.fill",
            "message.circle.fill", "envelope.fill", "envelope.circle.fill", "video.fill",
            "video.circle.fill", "bubble.left.fill", "bubble.right.fill", "hand.wave.fill",
            "hand.thumbsup.fill", "hand.thumbsdown.fill", "gift.fill",
            "person.badge.plus.fill", "person.crop.circle.fill", "at.circle.fill"
        ]),
        ("Entertainment", [
            "music.note", "music.note.list", "music.quarternote.3", "film.fill",
            "film.circle.fill", "gamecontroller.fill", "gamecontroller.circle.fill",
            "tv.fill", "tv.circle.fill", "headphones", "headphones.circle.fill",
            "mic.fill", "mic.circle.fill", "photo.fill", "photo.circle.fill",
            "camera.fill", "camera.circle.fill", "paintbrush.fill",
            "paintbrush.circle.fill", "book.closed.fill", "theatermasks.fill",
            "dice.fill", "puzzlepiece.fill", "guitars.fill"
        ]),
        ("Transport & Travel", [
            "car.fill", "car.circle.fill", "car.2.fill", "airplane", "airplane.circle.fill",
            "tram.fill", "bus.fill", "bus.circle.fill", "train.side.fill",
            "ferry.fill", "map.fill", "map.circle.fill", "location.fill",
            "location.circle.fill", "compass.fill", "signpost.right.fill",
            "bicycle.fill", "scooter.fill", "fuelpump.fill", "airplane.departure"
        ]),
        ("Finance & Shopping", [
            "dollarsign.circle.fill", "banknote.fill", "creditcard.fill",
            "creditcard.circle.fill", "chart.line.uptrend.xyaxis", "chart.pie.fill",
            "percent", "yensign.circle.fill", "sterlingsign.circle.fill",
            "eurosign.circle.fill", "indianrupeesign.circle.fill", "bitcoinsign.circle.fill",
            "wallet.pass.fill", "wallet.bifold.fill", "bag.badge.plus", "tag.circle.fill",
            "basket.fill", "chart.line.downtrend.xyaxis"
        ]),
        ("Technology & Internet", [
            "laptopcomputer", "laptopcomputer.and.iphone", "desktopcomputer",
            "iphone", "ipad", "apple.logo", "globe", "wifi", "wifi.circle.fill",
            "antenna.radiowaves.left.and.right", "server.rack", "externaldrive.fill",
            "opticaldiscdrive.fill", "xmark.icloud.fill", "printer.fill",
            "cpu.fill", "memorychip.fill", "scanner.fill"
        ]),
        ("Nature & Outdoor", [
            "tree.fill", "mountain.2.fill", "drop.circle.fill", "cloud.fill",
            "cloud.rain.fill", "cloud.snow.fill", "wind.snow", "bolt.fill",
            "snowflake", "tornado", "cloud.bolt.fill", "rainbow",
            "fish.fill", "bird.fill", "pawprint.fill", "hare.fill", "ant.fill"
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
        VStack(spacing: 0) {
            if visibleCategories.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView("No icons", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView.search(text: searchText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(visibleCategories, id: \.name) { category in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(category.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 16)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                                    ForEach(category.icons, id: \.self) { icon in
                                        Button(action: {
                                            selectedIcon = icon
                                            dismiss()
                                        }) {
                                            ZStack {
                                                if selectedIcon == icon {
                                                    Circle()
                                                        .fill(Color(hex: colorHex).opacity(0.2))
                                                }

                                                Image(systemName: icon)
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(selectedIcon == icon ? Color(hex: colorHex) : .primary)
                                            }
                                            .frame(height: 50)
                                            .contentShape(Circle())
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Choose Icon")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search icons")
    }
}
