import Foundation

struct GymWidgetSnapshot: Codable {
    let updatedAt: Date
    let referenceDate: Date
    let realStartDate: Date
    let scheduleMode: String
    let sequenceToWeekday: [String: String]
    let exercises: [WidgetExercise]
}

extension GymShared {
    static let widgetSnapshotKey = "gymapp.widget.snapshot.v2"

    static func writeWidgetSnapshot(referenceDate: Date, realStartDate: Date, scheduleMode: String, sequenceToWeekday: [String: String], exercises: [WidgetExercise]) {
        let snapshot = GymWidgetSnapshot(updatedAt: Date(), referenceDate: referenceDate, realStartDate: realStartDate, scheduleMode: scheduleMode, sequenceToWeekday: sequenceToWeekday, exercises: exercises)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults()?.set(data, forKey: widgetSnapshotKey)
        defaults()?.synchronize()
        UserDefaults.standard.set(data, forKey: widgetSnapshotKey)
    }

    static func readWidgetSnapshot() -> GymWidgetSnapshot? {
        let data = defaults()?.data(forKey: widgetSnapshotKey) ?? UserDefaults.standard.data(forKey: widgetSnapshotKey)
        guard let data, let snapshot = try? JSONDecoder().decode(GymWidgetSnapshot.self, from: data) else { return nil }
        return snapshot
    }
}
