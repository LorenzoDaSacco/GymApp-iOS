import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

enum GymShared {
    static let appGroup = "group.com.gymtrackerpro.shared"
    static let workoutsKey = "gymapp.native.v5"
    static let legacyKey = "gymapp.native.v4"
    static let selectedDayKey = "gymapp.selectedDay"
    static let scheduleModeKey = "gymapp.scheduleMode"

    static func defaults() -> UserDefaults? { UserDefaults(suiteName: appGroup) }
}

struct WidgetWorkoutSet: Codable {
    let reps: String
    let weight: Double
    let completed: Bool
}

struct WidgetExercise: Codable {
    let name: String
    let sets: [WidgetWorkoutSet]
    let recovery: String
}

enum WidgetDay {
    static let weekdays = ["LUNEDÌ", "MARTEDÌ", "MERCOLEDÌ", "GIOVEDÌ", "VENERDÌ", "SABATO", "DOMENICA"]
    static let numbered = (1...7).map { "GIORNO \($0)" }

    static func today(calendar: Calendar = .current, date: Date = Date()) -> String {
        let rawMode = GymShared.defaults()?.string(forKey: GymShared.scheduleModeKey) ?? "weekdays"
        let mode = ScheduleMode(rawValue: rawMode) ?? .weekdays
        if mode == .numbered {
            return selectedDayDisplay()
        }
        let n = calendar.component(.weekday, from: date)
        switch n {
        case 2: return weekdays[0]
        case 3: return weekdays[1]
        case 4: return weekdays[2]
        case 5: return weekdays[3]
        case 6: return weekdays[4]
        case 7: return weekdays[5]
        default: return weekdays[6]
        }
    }

    static func canonicalDay(for display: String) -> String {
        if let index = numbered.firstIndex(of: display) { return weekdays[index] }
        return display
    }

    private static func selectedDayDisplay() -> String {
        let raw = GymShared.defaults()?.string(forKey: GymShared.selectedDayKey) ?? weekdays[0]
        if let index = weekdays.firstIndex(of: raw) { return numbered[index] }
        if numbered.contains(raw) { return raw }
        return numbered[0]
    }
}

enum WidgetDataReader {
    static func todayExercises() -> [WidgetExercise] {
        guard let data = GymShared.defaults()?.data(forKey: GymShared.workoutsKey),
              let all = try? JSONDecoder().decode([Exercise].self, from: data) else { return [] }
        let day = WidgetDay.canonicalDay(for: WidgetDay.today())
        return all.filter { $0.day == day }.map {
            WidgetExercise(
                name: $0.name,
                sets: $0.sets.map { WidgetWorkoutSet(reps: $0.reps, weight: $0.weight, completed: $0.completed) },
                recovery: $0.recovery
            )
        }
    }

    static func completedSetsCount() -> (completed: Int, total: Int) {
        let exercises = todayExercises()
        let total = exercises.reduce(0) { $0 + $1.sets.count }
        let completed = exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        return (completed, total)
    }

    static func completedExercisesCount() -> (completed: Int, total: Int) {
        let exercises = todayExercises()
        let completed = exercises.filter { !$0.sets.isEmpty && $0.sets.allSatisfy(\.completed) }.count
        return (completed, exercises.count)
    }
}
