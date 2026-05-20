import SwiftUI
import SwiftData

@main
struct MuslimPlannerApp: App {
    @StateObject private var locationService = LocationService()
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([PlanTask.self, AppSettings.self, TaskTemplate.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationService)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                try? sharedModelContainer.mainContext.save()
            }
        }
    }
}
