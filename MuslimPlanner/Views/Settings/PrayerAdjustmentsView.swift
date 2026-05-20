import SwiftUI

// MARK: - Prayer list

struct PrayerAdjustmentsView: View {
    @Bindable var settings: AppSettings
    let rawPrayerTimes: [PrayerTime]

    private let prayerDefs: [(name: String, icon: String)] = [
        ("Fajr",    "moon.stars.fill"),
        ("Dhuhr",   "sun.max.fill"),
        ("Asr",     "sun.haze.fill"),
        ("Maghrib", "sunset.fill"),
        ("Isha",    "moon.fill"),
    ]

    var body: some View {
        List {
            Section {
                Text("Shift the calculated time by a fixed offset, or override it entirely with a custom time you choose.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(prayerDefs, id: \.name) { def in
                let raw = rawPrayerTimes.first { $0.name == def.name }
                NavigationLink {
                    PrayerAdjustmentEditor(settings: settings, name: def.name, icon: def.icon, rawTime: raw?.time)
                } label: {
                    prayerRow(name: def.name, icon: def.icon, rawTime: raw?.time)
                }
            }
        }
        .navigationTitle("Prayer Adjustments")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func prayerRow(name: String, icon: String, rawTime: Date?) -> some View {
        let fixedMins  = settings.fixedMinutes(for: name)
        let offsetMins = settings.offset(for: name)
        let isFixed    = fixedMins >= 0
        let hasAdjust  = isFixed || offsetMins != 0

        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                if isFixed {
                    let t = Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double(fixedMins) * 60)
                    Text("Fixed: \(t.formatted(.dateTime.hour().minute()))")
                        .font(.caption).foregroundStyle(.blue)
                } else if offsetMins != 0 {
                    Text(offsetMins > 0 ? "+\(offsetMins) min" : "\(offsetMins) min")
                        .font(.caption).foregroundStyle(offsetMins > 0 ? .green : .orange)
                } else if let raw = rawTime {
                    Text(raw.formatted(.dateTime.hour().minute()))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("No adjustment")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if hasAdjust {
                Image(systemName: "pencil.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue.opacity(0.7))
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Per-prayer editor

struct PrayerAdjustmentEditor: View {
    @Bindable var settings: AppSettings
    let name: String
    let icon: String
    let rawTime: Date?

    @State private var isFixed = false
    @State private var fixedDate = Date()
    @State private var offsetMinutes = 0

    var body: some View {
        Form {
            // Show calculated API time for reference
            if let raw = rawTime {
                Section {
                    LabeledContent("Calculated time", value: raw.formatted(.dateTime.hour().minute()))
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("From your location and calculation method.")
                }
            }

            // Fixed time toggle
            Section {
                Toggle("Use fixed time", isOn: $isFixed)
                    .onChange(of: isFixed) { _, _ in save() }

                if isFixed {
                    DatePicker("Time", selection: $fixedDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .onChange(of: fixedDate) { _, _ in save() }
                }
            } header: {
                Text("Fixed Time")
            } footer: {
                if isFixed {
                    Text("This exact time is used every day, ignoring location and calculation method.")
                } else {
                    Text("Override with a specific time that never changes.")
                }
            }

            // Offset — only relevant when not using a fixed time
            if !isFixed {
                Section {
                    HStack {
                        Button {
                            offsetMinutes = max(-120, offsetMinutes - 5)
                            save()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(offsetMinutes <= -120 ? Color.secondary.opacity(0.3) : .blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(offsetMinutes <= -120)

                        Spacer()

                        VStack(spacing: 2) {
                            Text(offsetMinutes == 0
                                 ? "No offset"
                                 : (offsetMinutes > 0 ? "+\(offsetMinutes) min" : "\(offsetMinutes) min"))
                                .font(.title3.monospacedDigit())
                            if offsetMinutes != 0, let raw = rawTime {
                                let adjusted = raw.addingTimeInterval(Double(offsetMinutes) * 60)
                                Text("→ \(adjusted.formatted(.dateTime.hour().minute()))")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }

                        Spacer()

                        Button {
                            offsetMinutes = min(120, offsetMinutes + 5)
                            save()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(offsetMinutes >= 120 ? Color.secondary.opacity(0.3) : .blue)
                        }
                        .buttonStyle(.plain)
                        .disabled(offsetMinutes >= 120)
                    }
                    .padding(.vertical, 6)

                    if offsetMinutes != 0 {
                        Button("Reset to no offset") {
                            offsetMinutes = 0
                            save()
                        }
                        .foregroundStyle(.red)
                    }
                } header: {
                    Text("Offset")
                } footer: {
                    Text("Shift the calculated time earlier (negative) or later (positive). Adjusts in 5-minute steps, ±120 min max.")
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { load() }
    }

    private func load() {
        let fixedMins = settings.fixedMinutes(for: name)
        isFixed = fixedMins >= 0
        offsetMinutes = settings.offset(for: name)

        let base = Calendar.current.startOfDay(for: Date())
        if fixedMins >= 0 {
            fixedDate = base.addingTimeInterval(Double(fixedMins) * 60)
        } else {
            fixedDate = rawTime ?? base.addingTimeInterval(6 * 3600)
        }
    }

    private func save() {
        if isFixed {
            let cal = Calendar.current
            let h = cal.component(.hour,   from: fixedDate)
            let m = cal.component(.minute, from: fixedDate)
            settings.setFixedMinutes(h * 60 + m, for: name)
        } else {
            settings.setFixedMinutes(-1, for: name)
            settings.setOffset(offsetMinutes, for: name)
        }
    }
}
