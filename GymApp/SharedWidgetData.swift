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
    /// Giorno della settimana reale a cui appartiene l'allenamento.
    /// È una copia esplicita del mapping calcolato dall'app, così il widget
    /// non deve ricostruire la relazione GIORNO X -> lunedì/domenica.
    let weekday: String?
    let name: String
    let sets: [WidgetWorkoutSet]
    let recovery: String

    init(day: String, weekday: String? = nil, name: String, sets: [WidgetWorkoutSet], recovery: String) {
        self.day = day
        self.weekday = weekday
        self.name = name
        self.sets = sets
        self.recovery = recovery
    }

    enum CodingKeys: String, CodingKey {
        case day, weekday, name, sets, recovery
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(String.self, forKey: .day)
        weekday = try c.decodeIfPresent(String.self, forKey: .weekday)
        name = try c.decode(String.self, forKey: .name)
        sets = try c.decode([WidgetWorkoutSet].self, forKey: .sets)
        recovery = try c.decode(String.self, forKey: .recovery)
    }
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
            // Prima scelta: il giorno della settimana è già stato calcolato
            // dall'app e memorizzato nell'esercizio. Questo evita qualsiasi
            // ambiguità tra GIORNO 1/2/3 e LUNEDÌ...DOMENICA.
            let weekday = normalizedDay(currentWeekday(at: date))
            let explicitWeekdayMatches = snapshot.exercises.filter {
                guard let exerciseWeekday = $0.weekday else { return false }
                return normalizedDay(exerciseWeekday) == weekday
            }
            if !explicitWeekdayMatches.isEmpty {
                return explicitWeekdayMatches
            }

            // Compatibilità con snapshot precedenti.
            let matching = snapshot.exercises.filter {
                normalizedDay($0.day) == normalizedTarget
            }
            if !matching.isEmpty {
                return matching
            }
        }

        let raw = rawExercises()
        guard !raw.isEmpty else { return [] }

        return raw.compactMap { exercise in
            guard normalizedDay(exercise.day) == normalizedTarget else { return nil }
            let weekday: String?
            if let snapshot = currentSnapshot(), snapshot.scheduleMode == ScheduleMode.trainingDays.rawValue {
                weekday = snapshot.sequenceToWeekday.first {
                    normalizedDay($0.key) == normalizedDay(exercise.day)
                }?.value
            } else {
                weekday = exercise.day
            }
            return WidgetExercise(
                day: exercise.day,
                weekday: weekday,
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
        // Fonte primaria: il riepilogo che l'app ha calcolato per il giorno
        // corrente. Evita qualsiasi ambiguita tra GIOVEDI e GIORNO X.
        if let snapshot = currentSnapshot() {
            let current = normalizedDay(currentWeekday(at: date))
            if normalizedDay(snapshot.todayWeekday) == current {
                let p = snapshot.todayProgress
                if p.totalExercises > 0 || p.totalSets > 0 {
                    return (p.completedSets, p.totalSets, p.completedExercises, p.totalExercises)
                }
            }
        }

        let exercises = todayExercises(at: date)
        if !exercises.isEmpty {
            let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
            let completedSets = exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
            let completedExercises = exercises.filter { !$0.sets.isEmpty && $0.sets.allSatisfy(\.completed) }.count
            return (completedSets, totalSets, completedExercises, exercises.count)
        }
        return (0, 0, 0, 0)
    }
}
