import Foundation
import SwiftData

@Model
final class TaskTemplate {
    var name: String
    var durationMinutes: Int
    var sortOrder: Int
    var colorHex: String
    var symbolName: String

    // Self-referential: no inverse annotation — SwiftData's auto-management is unreliable
    // for self-referential relationships. We set parent manually in all mutations.
    @Relationship(deleteRule: .cascade) var subtasks: [TaskTemplate] = []
    var parent: TaskTemplate?

    init(name: String, durationMinutes: Int = 30, sortOrder: Int = 0,
         colorHex: String = "007AFF", symbolName: String = "circle.fill") {
        self.name = name
        self.durationMinutes = durationMinutes
        self.sortOrder = sortOrder
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.subtasks = []
    }

    var isRoot: Bool { parent == nil }

    // Traverse up to the top-most ancestor
    var root: TaskTemplate {
        var current: TaskTemplate = self
        while let p = current.parent { current = p }
        return current
    }

    var sortedSubtasks: [TaskTemplate] {
        subtasks.sorted { $0.sortOrder < $1.sortOrder }
    }

    // Hierarchy path root → child: "Course Work → Assignment"
    var path: String {
        var parts: [String] = [name]
        var current = parent
        while let p = current {
            parts.insert(p.name, at: 0)
            current = p.parent
        }
        return parts.joined(separator: " → ")
    }

    // Task title for the timeline: child first: "Assignment - Course Work"
    var displayTitle: String {
        var parts: [String] = [name]
        var current = parent
        while let p = current {
            parts.append(p.name)
            current = p.parent
        }
        return parts.joined(separator: " - ")
    }
}
