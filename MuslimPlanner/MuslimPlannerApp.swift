import SwiftUI
import SwiftData

@main
struct MuslimPlannerApp: App {
    @StateObject private var locationService = LocationService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([PlanTask.self, Category.self, AppSettings.self])
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
    }
}
