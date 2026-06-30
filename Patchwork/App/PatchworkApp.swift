import SwiftUI
import SwiftData

@main
struct PatchworkApp: App {
    @StateObject private var appStore: AppStore
    @StateObject private var location: LocationService
    @StateObject private var store: StoreManager
    private let persistence: PersistenceController

    init() {
        let persistence = PersistenceController()
        let location = LocationService()
        let store = StoreManager()
        self.persistence = persistence
        _location = StateObject(wrappedValue: location)
        _store = StateObject(wrappedValue: store)
        _appStore = StateObject(wrappedValue: AppStore(
            modelContext: persistence.container.mainContext,
            location: location,
            store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appStore)
                .environmentObject(location)
                .environmentObject(store)
                .tint(Theme.Palette.accent)
                .task { await appStore.bootstrap() }
        }
        .modelContainer(persistence.container)
    }
}
