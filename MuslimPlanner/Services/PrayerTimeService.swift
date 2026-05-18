import Foundation

struct PrayerTime: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let time: Date
    let icon: String
    let blockName: String
}

// MARK: - Aladhan API decodables

private struct AladhanResponse: Decodable {
    let data: AladhanData
}

private struct AladhanData: Decodable {
    let timings: AladhanTimings
}

private struct AladhanTimings: Decodable {
    let Fajr: String
    let Dhuhr: String
    let Asr: String
    let Maghrib: String
    let Isha: String
}

// MARK: - Service

final class PrayerTimeService {

    static let calculationMethods: [(id: Int, name: String)] = [
        (1, "Muslim World League"),
        (2, "ISNA (North America)"),
        (3, "Egyptian Authority"),
        (4, "Umm Al-Qura (Mecca)"),
        (5, "Karachi University"),
    ]

    func fetchPrayerTimes(
        latitude: Double,
        longitude: Double,
        method: Int,
        date: Date
    ) async throws -> [PrayerTime] {
        let timestamp = Int(date.timeIntervalSince1970)
        var comps = URLComponents(string: "https://api.aladhan.com/v1/timings/\(timestamp)")!
        comps.queryItems = [
            URLQueryItem(name: "latitude",  value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "method",    value: String(method)),
        ]
        guard let url = comps.url else { throw URLError(.badURL) }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response  = try JSONDecoder().decode(AladhanResponse.self, from: data)
        let timings   = response.data.timings

        let cal = Calendar.current
        let baseDC = cal.dateComponents([.year, .month, .day], from: date)

        func parse(_ str: String) -> Date {
            // Aladhan returns "HH:mm" or "HH:mm (BST)" — take first two components
            let clean = str.components(separatedBy: " ").first ?? str
            let parts = clean.split(separator: ":").compactMap { Int($0) }
            guard parts.count >= 2 else { return date }
            var dc = baseDC
            dc.hour   = parts[0]
            dc.minute = parts[1]
            return cal.date(from: dc) ?? date
        }

        return [
            PrayerTime(name: "Fajr",    time: parse(timings.Fajr),    icon: "moon.stars.fill", blockName: "Fajr"),
            PrayerTime(name: "Dhuhr",   time: parse(timings.Dhuhr),   icon: "sun.max.fill",    blockName: "Dhuhr"),
            PrayerTime(name: "Asr",     time: parse(timings.Asr),     icon: "sun.haze.fill",   blockName: "Asr"),
            PrayerTime(name: "Maghrib", time: parse(timings.Maghrib), icon: "sunset.fill",     blockName: "Maghrib"),
            PrayerTime(name: "Isha",    time: parse(timings.Isha),    icon: "moon.fill",       blockName: "Isha"),
        ]
    }
}
