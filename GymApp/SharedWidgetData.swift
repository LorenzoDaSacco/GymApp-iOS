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
    private static func actualWeekdayName(at date: Date = Date()) -> String {
        WidgetDay.today(calendar: .autoupdatingCurrent, date: date)
    }

    private static func rawExercises() -> [Exercise] {
        let defaults = GymShared.defaults()
        let data = defaults?.data(forKey: GymShared.workoutsKey)
            ?? UserDefaults.standard.data(forKey: GymShared.workoutsKey)
            ?? defaults?.data(forKey: GymShared.legacyKey)
            ?? UserDefaults.standard.data(forKey: GymShared.legacyKey)
        guard let data, let all = try? JSONDecoder().decode([Exercise].self, from: data) else { return [] }
        return all
    }

    private static func currentSnapshot() -> GymWidgetSnapshot? {
        GymShared.readWidgetSnapshot()
    }

    /// Restituisce il nome interno dell'allenamento corrispondente al vero
    /// giorno della settimana dell'iPhone. Nessuna data virtuale viene usata.
    private static func workoutDayForWeekday(at date: Date) -> String? {
        let weekday = actualWeekdayName(at: date)
        guard let snapshot = currentSnapshot() else { return weekday }

        if snapshot.scheduleMode == ScheduleMode.trainingDays.rawValue {
            // Modalità GIORNO 1, 2, 3...: usa l'associazione salvata nelle
            // impostazioni (es. GIORNO 1 -> GIOVEDÌ).
            if let trainingDay = snapshot.sequenceToWeekday.first(where: { $0.value == weekday })?.key {
                return trainingDay
            }
            // Fallback per dati creati da una versione precedente: se gli
            // esercizi sono ancora nominati con i giorni della settimana,
            // usiamo direttamente quel giorno.
            if snapshot.exercises.contains(where: { $0.day == weekday }) {
                return weekday
            }
            return nil
        }

        // Modalità calendario settimanale: il giorno dell'iPhone è
        // direttamente il giorno della scheda.
        return weekday
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

        // Preferiamo i dati live dell'App Group. Così il widget vede subito
        // l'ultimo allenamento/peso/serie salvato dall'app.
        let source: [WidgetExercise]
        let raw = rawExercises()
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
        let matches = source.filter { $0.day == targetDay }
        if !matches.isEmpty { return matches }

        // Ultimo fallback: se il mapping era stato salvato con un formato
        // precedente, prova comunque il vero giorno della settimana.
        let weekday = actualWeekdayName(at: date)
        return source.filter { $0.day == weekday }
    }

    static func todayProgress(at date: Date = Date()) -> (completedSets: Int, totalSets: Int, completedExercises: Int, totalExercises: Int) {
        let exercises = todayExercises(at: date)
        let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        let completedSets = exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        let completedExercises = exercises.filter { !$0.sets.isEmpty && $0.sets.allSatisfy(\.completed) }.count
        return (completedSets, totalSets, completedExercises, exercises.count)
    }
}

