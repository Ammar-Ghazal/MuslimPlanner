import Foundation
import SwiftUI
import SwiftData

@Model
final class PlanTask {
    var title: String
    var date: Date
    var prayerBlock: String
    var startTime: Date?
    var durationMinutes: Int?
    var isCompleted: Bool
    var checklistItems: [String] = []
    var completedItemNames: [String] = []
    @Relationship(deleteRule: .nullify) var taskType: TaskTemplate?

    init(
        title: String,
        date: Date,
        prayerBlock: String,
        startTime: Date? = nil,
        durationMinutes: Int? = nil
    ) {
        self.title = title
        self.date = date
        self.prayerBlock = prayerBlock
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.isCompleted = false
        self.checklistItems = []
        self.completedItemNames = []
    }

    var color: Color {
        guard let hex = taskType?.colorHex else { return Color.blue }
        return Color(hex: hex)
    }

    var icon: String {
        taskType?.symbolName ?? "circle.fill"
    }

    var completedItems: Set<String> {
        Set(completedItemNames)
    }

    func setCompletedItems(_ items: Set<String>) {
        completedItemNames = Array(items).sorted()
    }
}


