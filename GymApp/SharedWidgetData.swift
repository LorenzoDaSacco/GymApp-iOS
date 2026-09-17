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
    private static let sequenceMapKey = "gymapp.sequenceMap.v1"

    private static func normalizedDay(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .uppercased()
    }

    private static func currentWeekday(at date: Date) -> String {
        WidgetDay.today(calendar: .autoupdatingCurrent, date: date)
    }

    private static func readSharedData(_ key: String) -> Data? {
        GymShared.defaults()?.data(forKey: key)
    }

    private static func readAnyData(_ key: String) -> Data? {
        readSharedData(key) ?? UserDefaults.standard.data(forKey: key)
    }

    private static func rawExercises() -> [Exercise] {
        // Il widget usa il contenitore App Group come fonte primaria.
        // Il fallback standard serve solo per compatibilità con vecchie versioni.
        for key in [GymShared.workoutsKey, GymShared.legacyKey] {
            if let data = readAnyData(key),
               let all = try? JSONDecoder().decode([Exercise].self, from: data) {
                return all
            }
        }
        return []
    }

    private static func currentSnapshot() -> GymWidgetSnapshot? {
        GymShared.readWidgetSnapshot()
    }

    private static func sharedSequenceMap() -> [String: String] {
        if let map = GymShared.defaults()?.dictionary(forKey: sequenceMapKey) as? [String: String] {
            return map
        }
        if let map = UserDefaults.standard.dictionary(forKey: sequenceMapKey) as? [String: String] {
            return map
        }
        return [:]
    }

    /// Determina l'allenamento di oggi esclusivamente dalla data reale dell'iPhone.
    /// In modalità settimanale: giovedì -> GIOVEDÌ.
    /// In modalità GIORNO 1,2,3: giovedì -> il GIORNO X associato a GIOVEDÌ.
    private static func workoutDay(at date: Date) -> String? {
        let weekday = currentWeekday(at: date)
        let snapshot = currentSnapshot()
        let mode = snapshot?.scheduleMode ?? ScheduleMode.weekdays.rawValue

        if mode == ScheduleMode.weekdays.rawValue {
            return weekday
        }

        let map: [String: String]
        if let snapshotMap = snapshot?.sequenceToWeekday, !snapshotMap.isEmpty {
            map = snapshotMap
        } else {
            map = sharedSequenceMap()
        }

        let normalizedWeekday = normalizedDay(weekday)
        return map.first { normalizedDay($0.value) == normalizedWeekday }?.key
    }

    static func allExercises() -> [Exercise] { rawExercises() }

    static func currentWorkoutDay(at date: Date = Date()) -> String? {
        workoutDay(at: date)
    }

    static func currentWorkoutDayLabel(at date: Date = Date()) -> String {
        workoutDay(at: date) ?? "GIORNO LIBERO"
    }

    /// Legge prima lo snapshot App Group, che contiene esattamente i dati che
    /// l'app ha appena salvato per il widget. Solo dopo prova il vecchio JSON.
    /// Questo evita che un decode parziale/vecchio del modello Exercise faccia
    /// apparire 0/0 quando l'app contiene invece gli esercizi corretti.
    static func todayExercises(at date: Date = Date()) -> [WidgetExercise] {
        guard let targetDay = workoutDay(at: date) else { return [] }
        let normalizedTarget = normalizedDay(targetDay)

        if let snapshot = currentSnapshot() {
            let matching = snapshot.exercises.filter {
                normalizedDay($0.day) == normalizedTarget
            }
            if !matching.isEmpty || !snapshot.exercises.isEmpty {
                return matching
            }
        }

        let raw = rawExercises()
        guard !raw.isEmpty else { return [] }

        return raw.compactMap { exercise in
            guard normalizedDay(exercise.day) == normalizedTarget else { return nil }
            return WidgetExercise(
                day: exercise.day,
                name: exercise.name,
                sets: exercise.sets.map {
                    WidgetWorkoutSet(
                        reps: $0.reps,
                        weight: $0.weight,
                        completed: $0.completed
                    )
                },
                recovery: exercise.recovery
            )
        }
    }

    static func todayProgress(at date: Date = Date()) -> (completedSets: Int, totalSets: Int, completedExercises: Int, totalExercises: Int) {
        let weekday = currentWeekday(at: date)
        let snapshot = currentSnapshot()

        // Fonte primaria: i numeri già calcolati dall'app per ogni giorno.
        // Non dipende dal decoder del modello Exercise nel widget.
        if let direct = snapshot?.dailyProgress {
            let normalized = normalizedDay(weekday)
            if let value = direct.first(where: { normalizedDay($0.key) == normalized })?.value {
                return (value.completedSets, value.totalSets, value.completedExercises, value.totalExercises)
            }
        }

        let exercises = todayExercises(at: date)
        let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        let completedSets = exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        let completedExercises = exercises.filter { !$0.sets.isEmpty && $0.sets.allSatisfy(\.completed) }.count
        return (completedSets, totalSets, completedExercises, exercises.count)
    }
}
