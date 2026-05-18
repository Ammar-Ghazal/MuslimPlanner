import SwiftUI
import SwiftData

struct TaskTypeManagerView: View {
    @Query(sort: \TaskTemplate.name) private var templates: [TaskTemplate]
    @Environment(\.modelContext) private var ctx

    @State private var editingTemplate: TaskTemplate?
    @State private var showEditor = false

    var body: some View {
        List {
            ForEach(templates) { template in
                Button {
                    editingTemplate = template
                    showEditor = true
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(template.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(template.durationMinutes)m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !template.subtasks.isEmpty {
                            Text(template.sortedSubtasks.map(\.name).joined(separator: " → "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .onDelete { idxs in
                for i in idxs { ctx.delete(templates[i]) }
            }
        }
        .navigationTitle("Task Types")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingTemplate = nil
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
            TaskTemplateEditorSheet(template: editingTemplate)
                .onDisappear { editingTemplate = nil }
        }
    }
}
