import SwiftUI
import UIKit

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @EnvironmentObject var locationService: LocationService

    var body: some View {
        NavigationStack {
            Form {
                // Reminder offset
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Reminder", systemImage: "bell.fill")
                            Spacer()
                            Text(settings.notificationOffsetMinutes == 0
                                 ? "Off"
                                 : "\(settings.notificationOffsetMinutes) min before")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get:  { Double(settings.notificationOffsetMinutes) },
                                set:  { settings.notificationOffsetMinutes = Int($0) }
                            ),
                            in: 0 ... 60,
                            step: 5
                        )
                        .tint(.green)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Receive an alert this many minutes before each prayer.")
                }

                // Calculation method
                Section("Prayer Calculation Method") {
                    ForEach(PrayerTimeService.calculationMethods, id: \.id) { method in
                        Button {
                            settings.calculationMethod = method.id
                        } label: {
                            HStack {
                                Text(method.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if settings.calculationMethod == method.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }

                // Location
                Section("Location") {
                    if locationService.isAuthorized {
                        HStack {
                            Label(locationService.cityName.isEmpty ? "Detected" : locationService.cityName,
                                  systemImage: "location.fill")
                            Spacer()
                            Button("Refresh") { locationService.fetchLocation() }
                                .font(.caption)
                        }
                    } else {
                        Label("Location access required", systemImage: "location.slash")
                            .foregroundStyle(.secondary)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                }

                // Categories
                Section {
                    NavigationLink("Manage Categories") {
                        CategoryManagerView()
                    }
                }

                // App info
                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
