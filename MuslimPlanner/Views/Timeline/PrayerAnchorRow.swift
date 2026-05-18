import SwiftUI

struct PrayerAnchorRow: View {
    let prayer: PrayerTime
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: prayer.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(prayerColor))

            VStack(alignment: .leading, spacing: 1) {
                Text(prayer.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(prayer.time.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(prayerColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(prayerColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(prayerColor.opacity(0.25), lineWidth: 1)
                )
        )
        .padding(.trailing, 12)
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
