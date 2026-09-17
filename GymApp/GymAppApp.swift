import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

@main
struct GymAppApp: App {
    @StateObject private var store = WorkoutStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            store.refreshSelectedDayForToday(force: true)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }
}
