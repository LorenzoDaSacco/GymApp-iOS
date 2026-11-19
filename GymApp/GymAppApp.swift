import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

@main
struct GymAppApp: App {
    @StateObject private var store = WorkoutStore()
    @StateObject private var heartMonitor = HeartRateMonitor()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store).environmentObject(heartMonitor)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive { heartMonitor.saveHistory() }
            guard phase == .active else { return }
            store.refreshSelectedDayForToday(force: true)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }
}
