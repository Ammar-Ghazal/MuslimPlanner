import Foundation
import SwiftData

@Model
final class PlanTask {
    var title: String
    var date: Date
    var prayerBlock: String
    var startTime: Date?
    var durationMinutes: Int?
    var isCompleted: Bool
    @Relationship(deleteRule: .nullify) var category: Category?

    init(
        title: String,
        date: Date,
        prayerBlock: String,
        startTime: Date? = nil,
        durationMinutes: Int? = nil,
        category: Category? = nil
    ) {
        self.title = title
        self.date = date
        self.prayerBlock = prayerBlock
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.isCompleted = false
        self.category = category
    }
}
