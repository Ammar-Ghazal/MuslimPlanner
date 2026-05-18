import UserNotifications
import Foundation

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestAuthorization() async {
        try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    func schedulePrayerReminders(prayerTimes: [PrayerTime], offsetMinutes: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: prayerTimes.map { "prayer_\($0.blockName)" })

        guard offsetMinutes > 0 else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        for prayer in prayerTimes {
            let triggerDate = prayer.time.addingTimeInterval(-Double(offsetMinutes) * 60)
            guard triggerDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(prayer.name) in \(offsetMinutes) min"
            content.body  = "Time to wrap up and prepare for \(prayer.name) prayer."
            content.sound = .default

            let dc = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
            let request = UNNotificationRequest(identifier: "prayer_\(prayer.blockName)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
