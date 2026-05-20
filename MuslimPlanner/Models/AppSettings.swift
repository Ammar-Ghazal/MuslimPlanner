import Foundation
import SwiftData

@Model
final class AppSettings {
    var calculationMethod: Int = 2
    var notificationOffsetMinutes: Int = 10
    var hasCompletedOnboarding: Bool = false
    var lastKnownLatitude: Double = 0
    var lastKnownLongitude: Double = 0

    // Per-prayer offset (minutes; positive = later, negative = earlier)
    var fajrOffsetMinutes: Int = 0
    var dhuhrOffsetMinutes: Int = 0
    var asrOffsetMinutes: Int = 0
    var maghribOffsetMinutes: Int = 0
    var ishaOffsetMinutes: Int = 0

    // Per-prayer fixed time override (-1 = not fixed; 0…1439 = minutes since midnight)
    var fajrFixedMinutes: Int = -1
    var dhuhrFixedMinutes: Int = -1
    var asrFixedMinutes: Int = -1
    var maghribFixedMinutes: Int = -1
    var ishaFixedMinutes: Int = -1

    init() {}

    func offset(for name: String) -> Int {
        switch name {
        case "Fajr":    return fajrOffsetMinutes
        case "Dhuhr":   return dhuhrOffsetMinutes
        case "Asr":     return asrOffsetMinutes
        case "Maghrib": return maghribOffsetMinutes
        case "Isha":    return ishaOffsetMinutes
        default: return 0
        }
    }

    func setOffset(_ value: Int, for name: String) {
        switch name {
        case "Fajr":    fajrOffsetMinutes    = value
        case "Dhuhr":   dhuhrOffsetMinutes   = value
        case "Asr":     asrOffsetMinutes     = value
        case "Maghrib": maghribOffsetMinutes  = value
        case "Isha":    ishaOffsetMinutes    = value
        default: break
        }
    }

    func fixedMinutes(for name: String) -> Int {
        switch name {
        case "Fajr":    return fajrFixedMinutes
        case "Dhuhr":   return dhuhrFixedMinutes
        case "Asr":     return asrFixedMinutes
        case "Maghrib": return maghribFixedMinutes
        case "Isha":    return ishaFixedMinutes
        default: return -1
        }
    }

    func setFixedMinutes(_ value: Int, for name: String) {
        switch name {
        case "Fajr":    fajrFixedMinutes    = value
        case "Dhuhr":   dhuhrFixedMinutes   = value
        case "Asr":     asrFixedMinutes     = value
        case "Maghrib": maghribFixedMinutes  = value
        case "Isha":    ishaFixedMinutes    = value
        default: break
        }
    }
}
