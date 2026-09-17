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

private func loadCalendarReference() -> GymShared.CalendarReference? {
    let defaults = GymShared.defaults()
    if let data = defaults?.data(forKey: GymShared.calendarReferenceKey),
       let value = try? JSONDecoder().decode(GymShared.CalendarReference.self, from: data) {
        return value
    }
    if let data = UserDefaults.standard.data(forKey: GymShared.calendarReferenceKey),
       let value = try? JSONDecoder().decode(GymShared.CalendarReference.self, from: data) {
        return value
    }
    return nil
}

func gymCalendarEffectiveDate(at now: Date = Date()) -> Date {
    // Il widget deve sempre usare la data reale dell'iPhone.
    // La correzione "Che giorno è?" resta disponibile nell'app, ma non deve
    // spostare il calendario reale del widget.
    now
}

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

    private static func normalizedDay(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "it_IT"))
            .uppercased()
    }

    private static func actualWeekdayName(at date: Date = Date()) -> String {
        // Questa è la sola fonte per sapere che giorno è: il calendario reale
        // dell'iPhone. Calendar.autoupdatingCurrent segue automaticamente
        // fuso orario e cambio di data a mezzanotte.
        WidgetDay.today(calendar: .autoupdatingCurrent, date: date)
    }

    private static func rawExercises() -> [Exercise] {
        // Il widget legge prima ed esclusivamente l'App Group condiviso.
        // UserDefaults.standard è usato solo come fallback per installazioni
        // precedenti in cui i dati erano stati salvati fuori dall'App Group.
        let defaults = GymShared.defaults()
        let data = defaults?.data(forKey: GymShared.workoutsKey)
            ?? defaults?.data(forKey: GymShared.legacyKey)
            ?? UserDefaults.standard.data(forKey: GymShared.workoutsKey)
            ?? UserDefaults.standard.data(forKey: GymShared.legacyKey)
        guard let data, let all = try? JSONDecoder().decode([Exercise].self, from: data) else { return [] }
        return all
    }

    private static func currentSnapshot() -> GymWidgetSnapshot? {
        GymShared.readWidgetSnapshot()
    }

    private static func sequenceMapFromSharedDefaults() -> [String: String] {
        let key = "gymapp.sequenceMap.v1"
        let defaults = GymShared.defaults()
        return (defaults?.dictionary(forKey: key) as? [String: String])
            ?? (UserDefaults.standard.dictionary(forKey: key) as? [String: String])
            ?? [:]
    }

    /// Restituisce l'identificatore dell'allenamento che corrisponde al vero
    /// giorno della settimana dell'iPhone.
    private static func workoutDayForWeekday(at date: Date) -> String? {
        let weekday = actualWeekdayName(at: date)
        let normalizedWeekday = normalizedDay(weekday)
        let snapshot = currentSnapshot()

        // Calendario settimanale: GIOVEDÌ significa sempre GIOVEDÌ.
        if snapshot?.scheduleMode != ScheduleMode.trainingDays.rawValue {
            return weekday
        }

        // Modalità GIORNO 1, 2, 3...: il calendario delle impostazioni associa
        // ogni GIORNO X a un giorno reale della settimana.
        let map = snapshot?.sequenceToWeekday.isEmpty == false
            ? snapshot!.sequenceToWeekday
            : sequenceMapFromSharedDefaults()

        if let trainingDay = map.first(where: { normalizedDay($0.value) == normalizedWeekday })?.key {
            return trainingDay
        }

        return nil
    }

    static func allExercises() -> [Exercise] { rawExercises() }

    static func currentWorkoutDay(at date: Date = Date()) -> String? {
        workoutDayForWeekday(at: date)
    }

    static func currentWorkoutDayLabel(at date: Date = Date()) -> String {
        currentWorkoutDay(at: date) ?? "GIORNO LIBERO"
    }

    static func todayExercises(at date: Date = Date()) -> [WidgetExercise] {
        let targetDay = currentWorkoutDay(at: date)
        let snapshot = currentSnapshot()

        let raw = rawExercises()
        let source: [WidgetExercise]
        if !raw.isEmpty {
            source = raw.map { exercise in
                WidgetExercise(
                    day: exercise.day,
                    name: exercise.name,
                    sets: exercise.sets.map { WidgetWorkoutSet(reps: $0.reps, weight: $0.weight, completed: $0.completed) },
                    recovery: exercise.recovery
                )
            }
        } else {
            source = snapshot?.exercises ?? []
        }

        guard let targetDay else { return [] }
        let normalizedTarget = normalizedDay(targetDay)

        // Confronto normalizzato: evita che accenti, maiuscole/minuscole o
        // vecchi salvataggi (es. GIOVEDI invece di GIOVEDÌ) facciano risultare 0.
        return source.filter { normalizedDay($0.day) == normalizedTarget }
    }

    static func todayProgress(at date: Date = Date()) -> (completedSets: Int, totalSets: Int, completedExercises: Int, totalExercises: Int) {
        let exercises = todayExercises(at: date)
        let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        let completedSets = exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        let completedExercises = exercises.filter { !$0.sets.isEmpty && $0.sets.allSatisfy(\.completed) }.count
        return (completedSets, totalSets, completedExercises, exercises.count)
    }
}
