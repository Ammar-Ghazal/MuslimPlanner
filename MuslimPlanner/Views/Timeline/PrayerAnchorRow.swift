import SwiftUI

struct PrayerAnchorRow: View {
    let prayer: PrayerTime

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: prayer.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(prayerColor)

            Text(prayer.name)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(prayerColor)

            Text(prayer.time.formatted(.dateTime.hour().minute()))
                .font(.system(size: 10))
                .foregroundStyle(prayerColor.opacity(0.8))

            Rectangle()
                .fill(prayerColor.opacity(0.4))
                .frame(height: 1)
        }
    }

    private var prayerColor: Color {
        switch prayer.blockName {
        case "Fajr":    return .indigo
        case "Dhuhr":   return .orange
        case "Asr":     return .yellow
        case "Maghrib": return .pink
        case "Isha":    return .purple
        default:        return .green
        }
    }
}
