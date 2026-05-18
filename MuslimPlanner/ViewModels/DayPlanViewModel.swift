import Foundation
import Combine

@MainActor
final class DayPlanViewModel: ObservableObject {
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var prayerTimes: [PrayerTime] = []
    @Published var isLoadingPrayers = false
    @Published var prayerError: String?

    private let prayerService = PrayerTimeService()
    let locationService: LocationService

    init(locationService: LocationService) {
        self.locationService = locationService
    }

    func loadPrayerTimes(settings: AppSettings) async {
        let lat = locationService.location?.coordinate.latitude  ?? settings.lastKnownLatitude
        let lon = locationService.location?.coordinate.longitude ?? settings.lastKnownLongitude
        guard lat != 0 || lon != 0 else {
            prayerError = "Location unavailable — enable Location access in Settings."
            return
        }

        isLoadingPrayers = true
        prayerError = nil
        defer { isLoadingPrayers = false }

        do {
            prayerTimes = try await prayerService.fetchPrayerTimes(
                latitude: lat,
                longitude: lon,
                method: settings.calculationMethod,
                date: selectedDate
            )
            saveLocation(to: settings)
            await NotificationService.shared.schedulePrayerReminders(
                prayerTimes: prayerTimes,
                offsetMinutes: settings.notificationOffsetMinutes
            )
        } catch {
            prayerError = "Could not load prayer times. Check your connection."
        }
    }

    func nextPrayer() -> PrayerTime? {
        prayerTimes.first { $0.time > Date() }
    }

    func countdownText() -> String? {
        guard let next = nextPrayer() else { return nil }
        let diff = Int(next.time.timeIntervalSince(Date()))
        guard diff > 0 else { return nil }
        let h = diff / 3600
        let m = (diff % 3600) / 60
        return h > 0 ? "\(h)h \(m)m until \(next.name)" : "\(m)m until \(next.name)"
    }

    func prayerBlock(containing date: Date) -> String {
        for (i, prayer) in prayerTimes.enumerated() {
            let nextTime = i + 1 < prayerTimes.count ? prayerTimes[i + 1].time : Date.distantFuture
            if date >= prayer.time && date < nextTime {
                return prayer.blockName
            }
        }
        return prayerTimes.first?.blockName ?? "Fajr"
    }

    private func saveLocation(to settings: AppSettings) {
        guard let loc = locationService.location else { return }
        settings.lastKnownLatitude  = loc.coordinate.latitude
        settings.lastKnownLongitude = loc.coordinate.longitude
    }
}
