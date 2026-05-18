import SwiftUI
import SwiftData

struct TaskTypePickerSheet: View {
    let date: Date
    let prayerTimes: [PrayerTime]

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskTemplate.name) private var allTemplates: [TaskTemplate]

    @State private var editorTemplate: TaskTemplate? = nil
    @State private var showCustomEditor = false

    // Only show root-level templates in the top list
    private var rootTemplates: [TaskTemplate] {
        allTemplates.filter { $0.isRoot }
    }

    var body: some View {
        NavigationStack {
            List {
                // Blank task
                Section {
                    Button {
                        showCustomEditor = true
                    } label: {
                        Label("Custom Task", systemImage: "square.and.pencil")
                            .foregroundStyle(.primary)
                    }
                }

                // Task types (root only)
                if rootTemplates.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Task Types",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Use Manage Task Types to create reusable templates.")
                        )
                    }
                } else {
                    Section("Task Types") {
                        ForEach(rootTemplates) { template in
                            if template.subtasks.isEmpty {
                                // No subtasks — tap directly opens editor
                                Button {
                                    editorTemplate = template
                                } label: {
                                    HStack {
                                        Text(template.name).foregroundStyle(.primary)
                                        Spacer()
                                        Text("\(template.durationMinutes)m")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            } else {
                                // Has subtasks — navigate to subtask selection
                                NavigationLink {
                                    SubtaskSelectionView(parent: template) { chosen in
                                        editorTemplate = chosen
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(template.name).foregroundStyle(.primary)
                                            Text("\(template.subtasks.count) subtask\(template.subtasks.count == 1 ? "" : "s")")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("\(template.durationMinutes)m")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    NavigationLink {
                        TaskTypeManagerView()
                    } label: {
                        Label("Manage Task Types", systemImage: "gearshape")
                            .foregroundStyle(.secondary)
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
            // Editor opens when a template is chosen (at any level)
            .sheet(item: $editorTemplate) { template in
                TaskEditorSheet(
                    task: nil,
                    prefill: template,
                    onSave: { dismiss() },
                    date: date,
                    prayerTimes: prayerTimes
                )
            }
            // Blank custom editor
            .sheet(isPresented: $showCustomEditor) {
                TaskEditorSheet(
                    task: nil,
                    onSave: { dismiss() },
                    date: date,
                    prayerTimes: prayerTimes
                )
            }
        }
    }
}

// MARK: - Subtask selection (pushed when parent has subtasks)

private struct SubtaskSelectionView: View {
    let parent: TaskTemplate
    let onChoose: (TaskTemplate) -> Void

    var body: some View {
        List {
            // Option: keep as the parent task, no subtask
            Section {
                Button {
                    onChoose(parent)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(parent.name)
                                .foregroundStyle(.primary)
                            Text("No subtask")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text("\(parent.durationMinutes)m")
                            .font(.caption).foregroundStyle(.secondary)
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }

            // Subtask options
            Section("Choose Subtask") {
                ForEach(parent.sortedSubtasks) { sub in
                    Button {
                        onChoose(sub)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.name)
                                    .foregroundStyle(.primary)
                                // Show the full path as a preview
                                Text(sub.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(sub.durationMinutes)m")
                                .font(.caption).foregroundStyle(.secondary)
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle(parent.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
