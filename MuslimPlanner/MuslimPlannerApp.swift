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
            // Schema migration failed (e.g. new columns added to a model).
            // Wipe the existing store so the app can relaunch cleanly.
            // Tasks and templates will be lost, but the app won't crash.
            let storeURL = config.url
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
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
