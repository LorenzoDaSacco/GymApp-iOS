import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

enum GymShared {
    static let appGroup = "group.com.gymtrackerpro.shared"
    static let workoutsKey = "gymapp.native.v5"
    static let legacyKey = "gymapp.native.v4"

    static func defaults() -> UserDefaults? { UserDefaults(suiteName: appGroup) }
}

struct WidgetWorkoutSet: Codable { let reps: String; let weight: Double; let completed: Bool }
struct WidgetExercise: Codable { let name: String; let sets: [WidgetWorkoutSet]; let recovery: String }

enum WidgetDay {
    static let all = ["LUNEDÌ", "MARTEDÌ", "MERCOLEDÌ", "GIOVEDÌ", "VENERDÌ", "SABATO", "DOMENICA"]
    static func today(calendar: Calendar = .current, date: Date = Date()) -> String {
        let n = calendar.component(.weekday, from: date)
        switch n { case 2: return all[0]; case 3: return all[1]; case 4: return all[2]; case 5: return all[3]; case 6: return all[4]; case 7: return all[5]; default: return all[6] }
    }
}

enum WidgetDataReader {
    static func todayExercises() -> [WidgetExercise] {
        guard let data = GymShared.defaults()?.data(forKey: GymShared.workoutsKey), let all = try? JSONDecoder().decode([Exercise].self, from: data) else { return [] }
        let day = WidgetDay.today()
        return all.filter { $0.day == day }.map { WidgetExercise(name: $0.name, sets: $0.sets.map { WidgetWorkoutSet(reps: $0.reps, weight: $0.weight, completed: $0.completed) }, recovery: $0.recovery) }
    }
}
