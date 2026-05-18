import SwiftUI

struct MainTabView: View {
    let settings: AppSettings
    @EnvironmentObject var locationService: LocationService
    @StateObject private var viewModel: DayPlanViewModel

    init(settings: AppSettings, locationService: LocationService) {
        self.settings = settings
        _viewModel = StateObject(wrappedValue: DayPlanViewModel(locationService: locationService))
    }

    var body: some View {
        content
            .task { await viewModel.loadPrayerTimes(settings: settings) }
            .onChange(of: viewModel.selectedDate) {
                Task { await viewModel.loadPrayerTimes(settings: settings) }
            }
            .onChange(of: settings.calculationMethod) {
                Task { await viewModel.loadPrayerTimes(settings: settings) }
            }
    }

    @ViewBuilder
    private var content: some View {
        #if targetEnvironment(macCatalyst)
        NavigationSplitView {
            List {
                NavigationLink("Timeline", destination: TimelineView(viewModel: viewModel, settings: settings))
                NavigationLink("Settings", destination: SettingsView(settings: settings))
            }
            .navigationTitle("Prayer Planner")
        } detail: {
            TimelineView(viewModel: viewModel, settings: settings)
        }
        #else
        TabView {
            TimelineView(viewModel: viewModel, settings: settings)
                .tabItem { Label("Today", systemImage: "calendar.day.timeline.left") }

            SettingsView(settings: settings)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        #endif
    }
}
