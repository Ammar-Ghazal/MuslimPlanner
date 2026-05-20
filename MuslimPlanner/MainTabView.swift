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
        TimelineView(viewModel: viewModel, settings: settings)
            .task { await viewModel.loadPrayerTimes(settings: settings) }
            .onChange(of: viewModel.selectedDate) {
                Task { await viewModel.loadPrayerTimes(settings: settings) }
            }
            .onChange(of: settings.calculationMethod) {
                Task { await viewModel.loadPrayerTimes(settings: settings) }
            }
    }
}
