import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum GymShared {
    static let appGroup = "group.com.gymtrackerpro.shared"
    static let workoutsKey = "gymapp.native.v5"
    static let legacyKey = "gymapp.native.v4"
    static let calendarReferenceKey = "gymapp.calendar.reference.v1"

    struct CalendarReference: Codable {
        let referenceDate: Date
        let realStartDate: Date
    }

    static func defaults() -> UserDefaults? { UserDefaults(suiteName: appGroup) }
}

struct WidgetWorkoutSet: Codable {
    let reps: String
    let weight: Double
    let completed: Bool
}

struct WidgetExercise: Codable {
    let day: String
    let name: String
    let sets: [WidgetWorkoutSet]
    let recovery: String
}

func gymCalendarEffectiveDate(at now: Date = Date()) -> Date { now }

enum WidgetDay {
    static let all = ["LUNEDÌ", "MARTEDÌ", "MERCOLEDÌ", "GIOVEDÌ", "VENERDÌ", "SABATO", "DOMENICA"]

    static func today(calendar: Calendar = .autoupdatingCurrent, date: Date = Date()) -> String {
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
    private static let weekdayNames = WidgetDay.all
    private static let sequenceMapKey = "gymapp.sequenceMap.v1"

    private static func normalizedDay(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .uppercased()
    }

    private static func currentWeekday(at date: Date) -> String {
        WidgetDay.today(calendar: .autoupdatingCurrent, date: date)
    }

    private static func readData(_ key: String) -> Data? {
        if let data = GymShared.defaults()?.data(forKey: key) { return data }
        return UserDefaults.standard.data(forKey: key)
    }

    private static func rawExercises() -> [Exercise] {
        for key in [GymShared.workoutsKey, GymShared.legacyKey] {
            if let data = readData(key), let all = try? JSONDecoder().decode([Exercise].self, from: data) {
                return all
            }
        }
        return []
    }

    private static func currentSnapshot() -> GymWidgetSnapshot? {
        GymShared.readWidgetSnapshot()
    }

    private static func sequenceMap() -> [String: String] {
        if let map = GymShared.defaults()?.dictionary(forKey: sequenceMapKey) as? [String: String] { return map }
        if let map = UserDefaults.standard.dictionary(forKey: sequenceMapKey) as? [String: String] { return map }
        return [:]
    }

    /// Una sola regola per tutti i widget:
    /// data reale dell'iPhone -> giorno della settimana -> allenamento.
    private static func workoutDay(at date: Date) -> String? {
        let weekday = currentWeekday(at: date)
        let snapshot = currentSnapshot()
        let mode = snapshot?.scheduleMode ?? ScheduleMode.weekdays.rawValue

        if mode == ScheduleMode.weekdays.rawValue {
            return weekday
        }

        let map = snapshot?.sequenceToWeekday.isEmpty == false
            ? snapshot!.sequenceToWeekday
            : sequenceMap()
        let normalizedWeekday = normalizedDay(weekday)
        return map.first(where: { normalizedDay($0.value) == normalizedWeekday })?.key
    }

    static func allExercises() -> [Exercise] { rawExercises() }

    static func currentWorkoutDay(at date: Date = Date()) -> String? {
        workoutDay(at: date)
    }

    static func currentWorkoutDayLabel(at date: Date = Date()) -> String {
        workoutDay(at: date) ?? "GIORNO LIBERO"
    }

    static func todayExercises(at date: Date = Date()) -> [WidgetExercise] {
        guard let targetDay = workoutDay(at: date) else { return [] }
        let normalizedTarget = normalizedDay(targetDay)

        // Preferisce sempre il JSON condiviso dell'app: è la fonte autorevole
        // e contiene lo stato aggiornato di completamento delle singole serie.
        let raw = rawExercises()
        if !raw.isEmpty {
            return raw.compactMap { exercise in
                guard normalizedDay(exercise.day) == normalizedTarget else { return nil }
                return WidgetExercise(
                    day: exercise.day,
                    name: exercise.name,
                    sets: exercise.sets.map { WidgetWorkoutSet(reps: $0.reps, weight: $0.weight, completed: $0.completed) },
                    recovery: exercise.recovery
                )
            }
        }

        // Fallback per dati di versioni precedenti.
        return (currentSnapshot()?.exercises ?? []).filter { normalizedDay($0.day) == normalizedTarget }
    }

    static func todayProgress(at date: Date = Date()) -> (completedSets: Int, totalSets: Int, completedExercises: Int, totalExercises: Int) {
        let exercises = todayExercises(at: date)
        let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        let completedSets = exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        let completedExercises = exercises.filter { !$0.sets.isEmpty && $0.sets.allSatisfy(\.completed) }.count
        return (completedSets, totalSets, completedExercises, exercises.count)
    }
}
