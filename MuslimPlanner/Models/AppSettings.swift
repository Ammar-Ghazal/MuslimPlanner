import Foundation
import SwiftData

@Model
final class AppSettings {
    var calculationMethod: Int
    var notificationOffsetMinutes: Int
    var hasCompletedOnboarding: Bool
    var lastKnownLatitude: Double
    var lastKnownLongitude: Double

    init() {
        calculationMethod = 2
        notificationOffsetMinutes = 10
        hasCompletedOnboarding = false
        lastKnownLatitude = 0
        lastKnownLongitude = 0
    }
}
