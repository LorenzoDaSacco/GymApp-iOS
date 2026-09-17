import SwiftUI

@main
struct GymAppApp: App {
    @StateObject private var store = WorkoutStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        RecoveryNotifications.shared.cleanupExpiredActivities()
                    }
                }
        }
    }
}
