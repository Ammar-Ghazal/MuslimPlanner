import SwiftUI
import SwiftData

struct TaskTypeManagerView: View {
    @Query(sort: \TaskTemplate.name) private var allTemplates: [TaskTemplate]
    @Environment(\.modelContext) private var ctx

    private var roots: [TaskTemplate] { allTemplates.filter(\.isRoot) }

    @State private var showEditor = false
    @State private var editing: TaskTemplate? = nil

    var body: some View {
        List {
            if roots.isEmpty {
                ContentUnavailableView(
                    "No Task Types",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Tap + to create your first task type.")
                )
            } else {
                ForEach(roots) { root in
                    Section {
                        // Root row
                        row(root, isSubtask: false)
                        // Subtask rows, visually indented
                        ForEach(root.sortedSubtasks) { sub in
                            row(sub, isSubtask: true)
                        }
                    }
                }
                .onDelete { idxs in
                    for i in idxs { ctx.delete(roots[i]) }
                    try? ctx.save()
                }
            }
        }
        .navigationTitle("Task Types")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editing = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showEditor) {
            TaskTemplateEditorSheet(template: editing)
                .onDisappear { editing = nil }
        }
    }

    @ViewBuilder
    private func row(_ t: TaskTemplate, isSubtask: Bool) -> some View {
        Button {
            editing = t
            showEditor = true
        } label: {
            HStack(spacing: 8) {
                if isSubtask {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 14)
                }
                Image(systemName: t.symbolName)
                    .foregroundStyle(Color(hex: t.colorHex))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.name).foregroundStyle(.primary)
                    if !t.subtasks.isEmpty {
                        Text(t.sortedSubtasks.map(\.name).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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
