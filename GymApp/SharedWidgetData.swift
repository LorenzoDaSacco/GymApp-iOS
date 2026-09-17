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
    guard let reference = loadCalendarReference() else { return now }
    let calendar = Calendar.current
    let realToday = calendar.startOfDay(for: now)
    let referenceRealDay = calendar.startOfDay(for: reference.realStartDate)
    let referenceDay = calendar.startOfDay(for: reference.referenceDate)
    let offset = calendar.dateComponents([.day], from: referenceRealDay, to: realToday).day ?? 0
    return calendar.date(byAdding: .day, value: offset, to: referenceDay) ?? reference.referenceDate
}

enum WidgetDay {
    static let all = ["LUNEDÌ", "MARTEDÌ", "MERCOLEDÌ", "GIOVEDÌ", "VENERDÌ", "SABATO", "DOMENICA"]
    static func today(calendar: Calendar = .current, date: Date = Date()) -> String {
        let effectiveDate = gymCalendarEffectiveDate(at: date)
        switch calendar.component(.weekday, from: effectiveDate) {
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

    private static func snapshotEffectiveDate(at date: Date) -> Date? {
        guard let snapshot = GymShared.readWidgetSnapshot() else { return nil }
        let calendar = Calendar.current
        let realToday = calendar.startOfDay(for: date)
        let realStart = calendar.startOfDay(for: snapshot.realStartDate)
        let reference = calendar.startOfDay(for: snapshot.referenceDate)
        let offset = calendar.dateComponents([.day], from: realStart, to: realToday).day ?? 0
        return calendar.date(byAdding: .day, value: offset, to: reference)
    }

    private static func snapshotWorkoutDay(at date: Date) -> String? {
        guard let snapshot = GymShared.readWidgetSnapshot() else { return nil }
        let effectiveDate = snapshotEffectiveDate(at: date) ?? date
        let calendar = Calendar.current
        let weekday: String
        switch calendar.component(.weekday, from: effectiveDate) {
        case 2: weekday = WidgetDay.all[0]
        case 3: weekday = WidgetDay.all[1]
        case 4: weekday = WidgetDay.all[2]
        case 5: weekday = WidgetDay.all[3]
        case 6: weekday = WidgetDay.all[4]
        case 7: weekday = WidgetDay.all[5]
        default: weekday = WidgetDay.all[6]
        }
        if snapshot.scheduleMode == ScheduleMode.trainingDays.rawValue {
            return snapshot.sequenceToWeekday.first(where: { $0.value == weekday })?.key
        }
        return weekday
    }

    static func allExercises() -> [Exercise] {
        guard let data = GymShared.defaults()?.data(forKey: GymShared.workoutsKey),
              let all = try? JSONDecoder().decode([Exercise].self, from: data) else { return [] }
        return all
    }

    static func currentWorkoutDay(at date: Date = Date()) -> String? {
        if let snapshot = GymShared.readWidgetSnapshot(), let day = snapshotWorkoutDay(at: date) { return day }
        return WidgetDay.today(date: date)
    }

    static func currentWorkoutDayLabel(at date: Date = Date()) -> String {
        currentWorkoutDay(at: date) ?? "GIORNO LIBERO"
    }

    static func todayExercises(at date: Date = Date()) -> [WidgetExercise] {
        guard let day = currentWorkoutDay(at: date) else { return [] }
        if let snapshot = GymShared.readWidgetSnapshot() {
            return snapshot.exercises.filter { $0.day == day }
        }
        return allExercises()
            .filter { $0.day == day }
            .map { exercise in
                WidgetExercise(day: exercise.day, name: exercise.name, sets: exercise.sets.map { WidgetWorkoutSet(reps: $0.reps, weight: $0.weight, completed: $0.completed) }, recovery: exercise.recovery)
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
