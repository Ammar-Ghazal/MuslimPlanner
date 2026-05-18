import Foundation
import SwiftData

@Model
final class TaskTemplate {
    var name: String
    var durationMinutes: Int
    var sortOrder: Int
    @Relationship(deleteRule: .nullify) var category: Category?
    @Relationship(deleteRule: .cascade, inverse: \TaskTemplate.parent) var subtasks: [TaskTemplate]
    var parent: TaskTemplate?

    init(name: String, durationMinutes: Int = 30, sortOrder: Int = 0) {
        self.name = name
        self.durationMinutes = durationMinutes
        self.sortOrder = sortOrder
        self.subtasks = []
    }

    var isRoot: Bool { parent == nil }

    var sortedSubtasks: [TaskTemplate] {
        subtasks.sorted { $0.sortOrder < $1.sortOrder }
    }

    var totalDurationMinutes: Int {
        durationMinutes + subtasks.reduce(0) { $0 + $1.totalDurationMinutes }
    }

    // Full display path from root, e.g. "Course Work → Assignment"
    var path: String {
        var parts: [String] = [name]
        var current = parent
        while let p = current {
            parts.insert(p.name, at: 0)
            current = p.parent
        }
        return parts.joined(separator: " → ")
    }
}
