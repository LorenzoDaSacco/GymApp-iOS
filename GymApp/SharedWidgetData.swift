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
    static let all = ["LUNEDÌ", "MARTEDÌ", "MERCOLEDÌ", "GIOVEDÌ", "VENERDÌ", "SABATO", "DOMENICA"]
    static func today(calendar: Calendar = .current, date: Date = Date()) -> String {
        switch calendar.component(.weekday, from: date) {
        case 2: return all[0]
        case 3: return all[1]
        case 4: return all[2]
        case 5: return all[3]
        case 6: return all[4]
        case 7: return all[5]
        default: return all[6]
        }
    }
}

enum WidgetDataReader {
    private struct SettingsPayload: Codable {
        let scheduleMode: ScheduleMode
        let repetitionMode: RepetitionMode
        let trainingDayCount: Int
    }

    static func allExercises() -> [Exercise] {
        guard let data = GymShared.defaults()?.data(forKey: GymShared.workoutsKey),
              let all = try? JSONDecoder().decode([Exercise].self, from: data) else { return [] }
        return all
    }

    static func currentWorkoutDay(at date: Date = Date()) -> String? {
        let weekday = WidgetDay.today(date: date)
        guard let data = GymShared.defaults()?.data(forKey: "gymapp.settings.v2") ?? UserDefaults.standard.data(forKey: "gymapp.settings.v2"),
              let settings = try? JSONDecoder().decode(SettingsPayload.self, from: data) else {
            return weekday
        }

        guard settings.scheduleMode == .trainingDays else {
            return weekday
        }

        guard let map = (GymShared.defaults()?.dictionary(forKey: "gymapp.sequenceMap.v1") as? [String: String]) ??
                        (UserDefaults.standard.dictionary(forKey: "gymapp.sequenceMap.v1") as? [String: String]) else {
            return nil
        }

        // In modalità GIORNO 1, 2, 3... il numero è legato al giorno
        // della settimana configurato dall'utente. Se oggi non è uno dei
        // giorni di allenamento, non mostriamo per errore GIORNO 1.
        return map.first(where: { $0.value == weekday })?.key
    }

    static func currentWorkoutDayLabel(at date: Date = Date()) -> String {
        currentWorkoutDay(at: date) ?? "GIORNO LIBERO"
    }

    static func todayExercises(at date: Date = Date()) -> [WidgetExercise] {
        guard let day = currentWorkoutDay(at: date) else { return [] }
        return allExercises()
            .filter { $0.day == day }
            .map { exercise in
                WidgetExercise(
                    name: exercise.name,
                    sets: exercise.sets.map { WidgetWorkoutSet(reps: $0.reps, weight: $0.weight, completed: $0.completed) },
                    recovery: exercise.recovery
                )
            }
    }

    static func todayProgress(at date: Date = Date()) -> (completedSets: Int, totalSets: Int, completedExercises: Int, totalExercises: Int) {
        let exercises = todayExercises(at: date)
        let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        let completedSets = exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        let completedExercises = exercises.filter { !$0.sets.isEmpty && $0.sets.allSatisfy(\.completed) }.count
        return (completedSets, totalSets, completedExercises, exercises.count)
    }
}
