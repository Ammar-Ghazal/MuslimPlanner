import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var settingsArray: [AppSettings]
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject var locationService: LocationService

    private var settings: AppSettings? { settingsArray.first }

    var body: some View {
        Group {
            if let s = settings {
                MainTabView(settings: s, locationService: locationService)
                    .fullScreenCover(
                        isPresented: Binding(
                            get: { !s.hasCompletedOnboarding },
                            set: { if !$0 { s.hasCompletedOnboarding = true } }
                        )
                    ) {
                        OnboardingView(settings: s)
                            .environmentObject(locationService)
                    }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if settingsArray.isEmpty {
                ctx.insert(AppSettings())
            }
        }
    }
}
