import Foundation

struct GymWidgetDayProgress: Codable {
    let completedExercises: Int
    let totalExercises: Int
    let completedSets: Int
    let totalSets: Int
}

struct GymWidgetSnapshot: Codable {
    let updatedAt: Date
    let referenceDate: Date
    let realStartDate: Date
    let scheduleMode: String
    let sequenceToWeekday: [String: String]
    let todayWeekday: String
    let todayWorkoutDay: String?
    let todayProgress: GymWidgetDayProgress
    let exercises: [WidgetExercise]
    let dailyProgress: [String: GymWidgetDayProgress]

    enum CodingKeys: String, CodingKey {
        case updatedAt, referenceDate, realStartDate, scheduleMode, sequenceToWeekday
        case todayWeekday, todayWorkoutDay, todayProgress, exercises, dailyProgress
    }

    init(updatedAt: Date, referenceDate: Date, realStartDate: Date, scheduleMode: String, sequenceToWeekday: [String: String], todayWeekday: String, todayWorkoutDay: String?, todayProgress: GymWidgetDayProgress, exercises: [WidgetExercise], dailyProgress: [String: GymWidgetDayProgress]) {
        self.updatedAt = updatedAt
        self.referenceDate = referenceDate
        self.realStartDate = realStartDate
        self.scheduleMode = scheduleMode
        self.sequenceToWeekday = sequenceToWeekday
        self.todayWeekday = todayWeekday
        self.todayWorkoutDay = todayWorkoutDay
        self.todayProgress = todayProgress
        self.exercises = exercises
        self.dailyProgress = dailyProgress
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        referenceDate = try c.decode(Date.self, forKey: .referenceDate)
        realStartDate = try c.decode(Date.self, forKey: .realStartDate)
        scheduleMode = try c.decode(String.self, forKey: .scheduleMode)
        sequenceToWeekday = try c.decode([String: String].self, forKey: .sequenceToWeekday)
        todayWeekday = try c.decodeIfPresent(String.self, forKey: .todayWeekday) ?? WidgetDay.today()
        todayWorkoutDay = try c.decodeIfPresent(String.self, forKey: .todayWorkoutDay)
        todayProgress = try c.decodeIfPresent(GymWidgetDayProgress.self, forKey: .todayProgress) ?? GymWidgetDayProgress(completedExercises: 0, totalExercises: 0, completedSets: 0, totalSets: 0)
        exercises = try c.decode([WidgetExercise].self, forKey: .exercises)
        dailyProgress = try c.decodeIfPresent([String: GymWidgetDayProgress].self, forKey: .dailyProgress) ?? [:]
    }
}

extension GymShared {
    static let widgetSnapshotKey = "gymapp.widget.snapshot.v3"

    static func writeWidgetSnapshot(referenceDate: Date, realStartDate: Date, scheduleMode: String, sequenceToWeekday: [String: String], todayWeekday: String, todayWorkoutDay: String?, todayProgress: GymWidgetDayProgress, exercises: [WidgetExercise], dailyProgress: [String: GymWidgetDayProgress]) {
        let snapshot = GymWidgetSnapshot(updatedAt: Date(), referenceDate: referenceDate, realStartDate: realStartDate, scheduleMode: scheduleMode, sequenceToWeekday: sequenceToWeekday, todayWeekday: todayWeekday, todayWorkoutDay: todayWorkoutDay, todayProgress: todayProgress, exercises: exercises, dailyProgress: dailyProgress)
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
