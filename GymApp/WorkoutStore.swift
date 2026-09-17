import Foundation
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

struct ExerciseSetSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let setIndex: Int
    let weight: Double
    let reps: Int
    let date: Date
    let isBackOff: Bool
    var volume: Double { weight * Double(reps) }
}

struct ExerciseSession: Codable, Equatable, Identifiable {
    let id: UUID
    let exerciseID: UUID
    let date: Date
    var sets: [ExerciseSetSnapshot]
    var totalVolume: Double { sets.reduce(0) { $0 + $1.volume } }
}

enum PerformanceStatus {
    case progress
    case maintain
    case decline

    var title: String {
        switch self {
        case .progress: return "PROGRESSO"
        case .maintain: return "MANTIENI"
        case .decline: return "PEGGIORAMENTO"
        }
    }
}

struct SetPerformanceComparison {
    let current: ExerciseSetSnapshot
    let previous: ExerciseSetSnapshot
    var weightDelta: Double { current.weight - previous.weight }
    var repsDelta: Int { current.reps - previous.reps }
    var volumeDelta: Double { current.volume - previous.volume }
}

struct PerformanceComparison {
    let status: PerformanceStatus
    let previous: ExerciseSession
    let current: ExerciseSession
    let sets: [SetPerformanceComparison]
    var volumeDeltaPercent: Double {
        guard previous.totalVolume > 0 else { return 0 }
        return ((current.totalVolume - previous.totalVolume) / previous.totalVolume) * 100
    }
}

@MainActor
final class WorkoutStore: ObservableObject {
    static let canonicalDays = ["LUNEDÌ", "MARTEDÌ", "MERCOLEDÌ", "GIOVEDÌ", "VENERDÌ", "SABATO", "DOMENICA"]
    static let numberedDays = (1...7).map { "GIORNO \($0)" }

    @Published var selectedDay = "LUNEDÌ" {
        didSet { UserDefaults.standard.set(selectedDay, forKey: "gymapp.selectedDay") }
    }
    @Published var exercises: [Exercise] = []
    @Published var scheduleMode: ScheduleMode = .weekdays {
        didSet {
            UserDefaults.standard.set(scheduleMode.rawValue, forKey: "gymapp.scheduleMode")
            if !Self.canonicalDays.contains(selectedDay) { selectedDay = Self.canonicalDays[0] }
        }
    }
    @Published var repSchemePreference: RepScheme = .general {
        didSet {
            UserDefaults.standard.set(repSchemePreference.rawValue, forKey: "gymapp.repScheme")
        }
    }

    private let key = GymShared.workoutsKey
    private let legacyKey = GymShared.legacyKey
    private let selectedDayKey = "gymapp.selectedDay"
    private let scheduleModeKey = "gymapp.scheduleMode"
    private let repSchemeKey = "gymapp.repScheme"
    private let sessionKey = "gymapp.exerciseSessions.v2"

    init() {
        if let raw = UserDefaults.standard.string(forKey: scheduleModeKey), let value = ScheduleMode(rawValue: raw) {
            scheduleMode = value
        }
        if let raw = UserDefaults.standard.string(forKey: repSchemeKey), let value = RepScheme(rawValue: raw) {
            repSchemePreference = value
        }
        if let saved = UserDefaults.standard.string(forKey: selectedDayKey), Self.canonicalDays.contains(saved) {
            selectedDay = saved
        }
        load()
        RecoveryNotifications.shared.requestPermission()
        if exercises.isEmpty {
            exercises = Self.initialSchedule()
            persist()
        }
    }

    var days: [String] { scheduleMode == .weekdays ? Self.canonicalDays : Self.numberedDays }
    var selectedDisplayDay: String { displayDay(forCanonical: selectedDay) }

    func displayDay(forCanonical canonical: String) -> String {
        guard let index = Self.canonicalDays.firstIndex(of: canonical) else { return canonical }
        return scheduleMode == .weekdays ? canonical : Self.numberedDays[index]
    }

    func canonicalDay(forDisplay display: String) -> String {
        if let index = Self.numberedDays.firstIndex(of: display) { return Self.canonicalDays[index] }
        return display
    }

    func selectDisplayDay(_ display: String) { selectedDay = canonicalDay(forDisplay: display) }

    func exercises(forDisplayDay display: String) -> [Exercise] {
        let canonical = canonicalDay(forDisplay: display)
        return exercises.filter { $0.day == canonical }
    }

    var dayExercises: [Exercise] { exercises.filter { $0.day == selectedDay } }
    var totalSets: Int { dayExercises.reduce(0) { $0 + $1.sets.count } }
    var completedSets: Int { dayExercises.reduce(0) { $0 + $1.sets.filter(\.completed).count } }
    var totalExercises: Int { dayExercises.count }
    var completedExercises: Int { dayExercises.filter { !$0.sets.isEmpty && $0.sets.allSatisfy(\.completed) }.count }

    func updateWeight(_ weight: Double, exerciseID: UUID, setID: UUID, saveHistory: Bool = true) {
        guard weight >= 0,
              let ei = exercises.firstIndex(where: { $0.id == exerciseID }),
              let si = exercises[ei].sets.firstIndex(where: { $0.id == setID }) else { return }
        if exercises[ei].sets[si].isBackOff { return }

        // Change only the selected set. No array-wide copy/reset is performed.
        let old = exercises[ei].sets[si].weight
        exercises[ei].sets[si].weight = weight
        if saveHistory && old != weight && weight > 0 {
            exercises[ei].sets[si].history.append(WeightLog(weight: weight))
        }
        refreshBackOff(ei)
        persist()
    }

    func setReps(_ reps: String, exerciseID: UUID, setID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }),
              let si = exercises[ei].sets.firstIndex(where: { $0.id == setID }) else { return }
        let filtered = reps.filter { $0.isNumber }
        exercises[ei].sets[si].reps = String(filtered.prefix(3))
        persist()
    }

    func setTargetReps(_ value: String, exerciseID: UUID, setIndex: Int) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }), exercises[ei].sets.indices.contains(setIndex) else { return }
        if exercises[ei].targetRepsBySet.count < exercises[ei].sets.count {
            exercises[ei].targetRepsBySet += Array(repeating: exercises[ei].generalTargetReps, count: exercises[ei].sets.count - exercises[ei].targetRepsBySet.count)
        }
        exercises[ei].targetRepsBySet[setIndex] = value
        persist()
    }

    func setRepScheme(_ scheme: RepScheme, exerciseID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[ei].repScheme = scheme
        if scheme == .specific {
            let general = exercises[ei].generalTargetReps
            exercises[ei].targetRepsBySet = exercises[ei].sets.indices.map { index in
                exercises[ei].targetRepsBySet.indices.contains(index) ? exercises[ei].targetRepsBySet[index] : general
            }
        }
        persist()
    }

    func applyRepSchemeToAll(_ scheme: RepScheme) {
        repSchemePreference = scheme
        for i in exercises.indices {
            exercises[i].repScheme = scheme
            let general = exercises[i].generalTargetReps
            if scheme == .specific {
                if exercises[i].targetRepsBySet.count < exercises[i].sets.count {
                    exercises[i].targetRepsBySet += Array(repeating: general, count: exercises[i].sets.count - exercises[i].targetRepsBySet.count)
                } else if exercises[i].targetRepsBySet.count > exercises[i].sets.count {
                    exercises[i].targetRepsBySet = Array(exercises[i].targetRepsBySet.prefix(exercises[i].sets.count))
                }
            } else {
                exercises[i].targetRepsBySet = Array(repeating: general, count: exercises[i].sets.count)
            }
        }
        persist()
    }

    func weight(exerciseID: UUID, setIndex: Int) -> Double {
        guard let exercise = exercises.first(where: { $0.id == exerciseID }), exercise.sets.indices.contains(setIndex) else { return 0 }
        return exercise.sets[setIndex].weight
    }

    func backOffWeight(exerciseID: UUID) -> Double {
        guard let exercise = exercises.first(where: { $0.id == exerciseID }), exercise.backOffEnabled, exercise.sets.count >= 2 else { return 0 }
        return roundedBackOff(exercise.sets[exercise.sets.count - 2].weight)
    }

    func setBackOffEnabled(_ enabled: Bool, exerciseID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        if enabled {
            guard !exercises[ei].backOffEnabled else { return }
            let source = exercises[ei].sets.last ?? WorkoutSet(reps: "", weight: 20)
            var backOff = WorkoutSet(reps: "", weight: roundedBackOff(source.weight), isBackOff: true)
            backOff.isBackOff = true
            exercises[ei].sets.append(backOff)
            exercises[ei].targetRepsBySet.append(exercises[ei].generalTargetReps)
            exercises[ei].backOffEnabled = true
            refreshBackOff(ei)
        } else {
            guard exercises[ei].backOffEnabled else { return }
            if let removed = exercises[ei].sets.popLast() { RecoveryNotifications.shared.cancel(for: removed.id) }
            if !exercises[ei].targetRepsBySet.isEmpty { exercises[ei].targetRepsBySet.removeLast() }
            exercises[ei].backOffEnabled = false
        }
        persist()
    }

    private func roundedBackOff(_ weight: Double) -> Double {
        guard weight > 0 else { return 0 }
        return (weight * 0.8 * 2).rounded() / 2
    }

    private func refreshBackOff(_ exerciseIndex: Int) {
        guard exercises.indices.contains(exerciseIndex), exercises[exerciseIndex].backOffEnabled, exercises[exerciseIndex].sets.count >= 2 else { return }
        let sourceIndex = exercises[exerciseIndex].sets.count - 2
        let backIndex = exercises[exerciseIndex].sets.count - 1
        exercises[exerciseIndex].sets[backIndex].weight = roundedBackOff(exercises[exerciseIndex].sets[sourceIndex].weight)
        exercises[exerciseIndex].sets[backIndex].reps = ""
        exercises[exerciseIndex].sets[backIndex].completed = false
        exercises[exerciseIndex].sets[backIndex].completedAt = nil
        exercises[exerciseIndex].sets[backIndex].isBackOff = true
    }

    func saveWeightHistory(weight: Double, exerciseID: UUID, setID: UUID) { updateWeight(weight, exerciseID: exerciseID, setID: setID, saveHistory: true) }

    func toggle(_ exerciseID: UUID, setID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }), let si = exercises[ei].sets.firstIndex(where: { $0.id == setID }) else { return }
        let reps = Int(exercises[ei].sets[si].reps) ?? 0
        let weight = exercises[ei].sets[si].weight
        let willComplete = !exercises[ei].sets[si].completed
        if willComplete && (reps <= 0 || weight <= 0) { return }

        exercises[ei].sets[si].completed = willComplete
        exercises[ei].sets[si].completedAt = willComplete ? Date() : nil
        persist()

        let exercise = exercises[ei]
        if willComplete {
            let recovery = exercise.recovery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "2:00" : exercise.recovery
            RecoveryNotifications.shared.start(for: setID, exerciseName: exercise.name, recovery: recovery)
        } else {
            RecoveryNotifications.shared.cancel(for: setID)
        }
        persist()
    }

    func addSet(to exerciseID: UUID) {
        guard let i = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        if exercises[i].backOffEnabled, let oldBackOff = exercises[i].sets.popLast() {
            RecoveryNotifications.shared.cancel(for: oldBackOff.id)
            let source = exercises[i].sets.last ?? WorkoutSet(reps: "", weight: 20)
            exercises[i].sets.append(WorkoutSet(reps: "", weight: source.weight))
            exercises[i].sets.append(WorkoutSet(reps: "", weight: roundedBackOff(source.weight), isBackOff: true))
            exercises[i].targetRepsBySet.append(exercises[i].generalTargetReps)
            exercises[i].targetRepsBySet.append(exercises[i].generalTargetReps)
            refreshBackOff(i)
        } else {
            let source = exercises[i].sets.last ?? WorkoutSet(reps: "", weight: 20)
            exercises[i].sets.append(WorkoutSet(reps: "", weight: source.weight))
            exercises[i].targetRepsBySet.append(exercises[i].generalTargetReps)
        }
        persist()
    }

    func removeSet(from exerciseID: UUID) {
        guard let i = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let regularCount = exercises[i].backOffEnabled ? exercises[i].sets.count - 1 : exercises[i].sets.count
        guard regularCount > 1 else { return }
        let index = exercises[i].backOffEnabled ? exercises[i].sets.count - 2 : exercises[i].sets.count - 1
        let removed = exercises[i].sets.remove(at: index)
        RecoveryNotifications.shared.cancel(for: removed.id)
        if exercises[i].targetRepsBySet.indices.contains(index) { exercises[i].targetRepsBySet.remove(at: index) }
        refreshBackOff(i)
        persist()
    }

    func setRecovery(_ recovery: String, exerciseID: UUID) {
        guard let i = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[i].recovery = recovery
        persist()
    }

    func moveExercise(_ exerciseID: UUID, day: String) {
        guard let i = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[i].day = canonicalDay(forDisplay: day)
        persist()
    }

    func addExercise(day: String, name: String, reps: String, weights: [Double], recovery: String = "", backOffEnabled: Bool = false, manualTarget: MuscleTarget? = nil, repScheme: RepScheme? = nil, targetRepsBySet: [String]? = nil) {
        let r = ExerciseRecognizer.recognize(name)
        let target = manualTarget ?? r.target
        let group = manualTarget == nil ? r.group : target.title
        let focus = manualTarget == nil ? r.focus : "Focus: \(target.title) · Inserito manualmente"
        let regularWeights = weights.isEmpty ? [20] : weights
        let scheme = repScheme ?? repSchemePreference
        let targets = targetRepsBySet ?? Array(repeating: reps, count: regularWeights.count)
        var e = Exercise(day: canonicalDay(forDisplay: day), name: name, group: group, focus: focus, target: target, reps: reps, numberOfSets: regularWeights.count, recovery: recovery, backOffEnabled: false, repScheme: scheme, targetRepsBySet: targets)
        e.sets = regularWeights.map { WorkoutSet(reps: "", weight: $0) }
        if backOffEnabled {
            e.sets.append(WorkoutSet(reps: "", weight: roundedBackOff(e.sets.last?.weight ?? 20), isBackOff: true))
            e.targetRepsBySet.append(reps)
            e.backOffEnabled = true
        }
        exercises.append(e)
        selectedDay = e.day
        persist()
    }

    func remove(_ exercise: Exercise) {
        for set in exercise.sets { RecoveryNotifications.shared.cancel(for: set.id) }
        exercises.removeAll { $0.id == exercise.id }
        persist()
    }

    func resetDay() {
        for i in exercises.indices where exercises[i].day == selectedDay {
            for j in exercises[i].sets.indices {
                exercises[i].sets[j].completed = false
                exercises[i].sets[j].completedAt = nil
                RecoveryNotifications.shared.cancel(for: exercises[i].sets[j].id)
            }
        }
        persist()
    }

    // MARK: Progressi

    func sessions(for exercise: Exercise) -> [ExerciseSession] {
        buildSessions(for: exercise).sorted { $0.date < $1.date }
    }

    func latestSession(for exercise: Exercise) -> ExerciseSession? { sessions(for: exercise).last }

    func previousSession(for exercise: Exercise) -> ExerciseSession? {
        let all = sessions(for: exercise)
        guard all.count >= 2 else { return nil }
        return all[all.count - 2]
    }

    func performance(for exercise: Exercise) -> PerformanceComparison? {
        guard let current = latestSession(for: exercise), let previous = previousSession(for: exercise) else { return nil }
        let pairs = zip(previous.sets.sorted { $0.setIndex < $1.setIndex }, current.sets.sorted { $0.setIndex < $1.setIndex }).map { SetPerformanceComparison(current: $1, previous: $0) }
        guard !pairs.isEmpty, current.sets.count >= previous.sets.count else { return nil }

        let lowerWeightCount = pairs.filter { $0.current.weight < $0.previous.weight }.count
        let higherWeightCount = pairs.filter { $0.current.weight > $0.previous.weight }.count
        let sameWeightHigherReps = pairs.filter { $0.current.weight >= $0.previous.weight && $0.current.reps > $0.previous.reps }.count
        let worseCount = pairs.filter { $0.current.weight < $0.previous.weight && $0.current.reps <= $0.previous.reps }.count
        let avgVolumeDelta = pairs.reduce(0) { $0 + $1.volumeDelta } / Double(pairs.count)
        let avgPreviousVolume = pairs.reduce(0) { $0 + $1.previous.volume } / Double(pairs.count)
        let volumePercent = avgPreviousVolume > 0 ? (avgVolumeDelta / avgPreviousVolume) * 100 : 0

        let status: PerformanceStatus
        // A lower load is never classified as progress merely because another set gained volume.
        if lowerWeightCount > higherWeightCount || worseCount >= max(1, pairs.count / 2 + 1) {
            status = .decline
        } else if volumePercent >= 3 || higherWeightCount > lowerWeightCount || sameWeightHigherReps >= max(1, pairs.count / 2) {
            status = .progress
        } else if volumePercent <= -5 {
            status = .decline
        } else {
            status = .maintain
        }

        return PerformanceComparison(status: status, previous: previous, current: current, sets: pairs)
    }

    func history(for exercise: Exercise) -> [WeightLog] {
        exercise.sets.flatMap { $0.history }.sorted { $0.date < $1.date }
    }

    func maxWeight(for exercise: Exercise) -> Double {
        max(history(for: exercise).map(\.weight).max() ?? 0, exercise.sets.map(\.weight).max() ?? 0)
    }

    func totalVolume(for exercise: Exercise) -> Double {
        sessions(for: exercise).reduce(0) { $0 + $1.totalVolume }
    }

    func todayVolume(for exercise: Exercise) -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        return sessions(for: exercise).first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })?.totalVolume ?? 0
    }

    func weeklyVolume(for target: MuscleTarget? = nil) -> Double {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return exercises.filter { target == nil || $0.target == target }.reduce(0) { partial, exercise in
            partial + sessions(for: exercise).filter { $0.date >= start }.reduce(0) { $0 + $1.totalVolume }
        }
    }

    private func buildSessions(for exercise: Exercise) -> [ExerciseSession] {
        var grouped: [Date: [ExerciseSetSnapshot]] = [:]
        let calendar = Calendar.current
        for (index, set) in exercise.sets.enumerated() where set.completed {
            let reps = Int(set.reps) ?? 0
            guard reps > 0, set.weight > 0 else { continue }
            let date = calendar.startOfDay(for: set.completedAt ?? Date())
            let snapshot = ExerciseSetSnapshot(id: set.id, setIndex: index, weight: set.weight, reps: reps, date: set.completedAt ?? date, isBackOff: set.isBackOff)
            grouped[date, default: []].append(snapshot)
        }
        return grouped.map { date, sets in
            ExerciseSession(id: UUID(uuidString: "\(exercise.id.uuidString.prefix(8))-\(date.timeIntervalSince1970.hashValue)".replacingOccurrences(of: "-", with: "")) ?? UUID(), exerciseID: exercise.id, date: date, sets: sets.sorted { $0.setIndex < $1.setIndex })
        }.sorted { $0.date < $1.date }
    }

    func persistChanges() { persist() }

    func backupData() -> Data? { try? JSONEncoder().encode(exercises) }

    func importBackup(data: Data) -> Bool {
        guard let decoded = try? JSONDecoder().decode([Exercise].self, from: data) else { return false }
        exercises = decoded
        persist()
        return true
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(exercises) else { return }
        UserDefaults.standard.set(data, forKey: key)
        GymShared.defaults()?.set(data, forKey: key)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func load() {
        let standard = UserDefaults.standard.data(forKey: key) ?? UserDefaults.standard.data(forKey: legacyKey)
        let shared = GymShared.defaults()?.data(forKey: key) ?? GymShared.defaults()?.data(forKey: legacyKey)
        if let data = standard ?? shared, let decoded = try? JSONDecoder().decode([Exercise].self, from: data) {
            var migrated = decoded
            for i in migrated.indices {
                // Repair old data whose last back-off flag existed but whose series was replaced.
                if migrated[i].backOffEnabled && (migrated[i].sets.last?.isBackOff != true) && migrated[i].sets.count > 1 {
                    migrated[i].sets.removeLast()
                    if !migrated[i].targetRepsBySet.isEmpty { migrated[i].targetRepsBySet.removeLast() }
                    migrated[i].backOffEnabled = false
                }
                if migrated[i].targetRepsBySet.count < migrated[i].sets.count {
                    migrated[i].targetRepsBySet += Array(repeating: migrated[i].generalTargetReps, count: migrated[i].sets.count - migrated[i].targetRepsBySet.count)
                }
                // Old data may have completed sets without a timestamp. Give those sets today's date
                // only when the old completion flag exists, so progress history is not lost.
                for j in migrated[i].sets.indices where migrated[i].sets[j].completed && migrated[i].sets[j].completedAt == nil {
                    migrated[i].sets[j].completedAt = Date()
                }
            }
            exercises = migrated
            persist()
        }
    }

    private static func initialSchedule() -> [Exercise] {
        func e(_ d: String, _ n: String, _ r: String, _ s: Int, _ g: String, _ f: String, _ t: MuscleTarget, _ rec: String) -> Exercise {
            Exercise(day: d, name: n, group: g, focus: f, target: t, reps: r, numberOfSets: s, recovery: rec, repScheme: .general)
        }
        return [
            e("LUNEDÌ", "Spinte manubri panca 32", "7-9", 3, "PETTO (ALTO)", "Pettorali superiori e tricipiti", .chest, "2:00"),
            e("LUNEDÌ", "Lat Pulldown", "7-9", 3, "DORSO", "Gran dorsale e bicipiti", .back, "2:00"),
            e("LUNEDÌ", "Chest Press", "8-10", 3, "PETTO", "Pettorali e tricipiti", .chest, "2:00"),
            e("LUNEDÌ", "T-Bar prona larga", "8-10", 3, "DORSO", "Dorsali e parte alta della schiena", .back, "2:00"),
            e("LUNEDÌ", "Alzate laterali", "10-12", 4, "SPALLE", "Deltoide laterale", .shoulders, "1:30"),
            e("LUNEDÌ", "Push Down asta curva", "10 RM", 4, "TRICIPITI", "Tricipite", .triceps, "1:30"),
            e("LUNEDÌ", "Curl cavo basso", "10 RM", 4, "BICIPITI", "Bicipite", .biceps, "1:30"),
            e("MARTEDÌ", "Leg Extension", "12 RM", 4, "QUADRICIPITI", "Quadricipite", .quads, "1:30"),
            e("MARTEDÌ", "Leg Press 45", "7-9", 3, "GAMBE", "Quadricipiti e glutei", .quads, "2:00"),
            e("MARTEDÌ", "Leg Curl sdraiato", "10-12", 2, "FEMORALI", "Femorali", .hamstrings, "1:30"),
            e("MARTEDÌ", "Adduttori", "10-12", 2, "ADDUTTORI", "Adduttori", .quads, "1:30"),
            e("MARTEDÌ", "Calf Machine", "8-10", 4, "POLPACCI", "Polpacci", .hamstrings, "1:30"),
            e("MERCOLEDÌ", "Panca piana bilanciere", "7-9", 4, "PETTO", "Pettorali e tricipiti", .chest, "2:30"),
            e("MERCOLEDÌ", "Rematore bilanciere", "7-9", 3, "DORSO", "Dorsali e parte alta della schiena", .back, "2:00"),
            e("MERCOLEDÌ", "Lento avanti manubri panca 71", "8-10", 3, "SPALLE", "Deltoidi e tricipiti", .shoulders, "2:00"),
            e("MERCOLEDÌ", "Rowing", "8-10", 3, "DORSO", "Schiena", .back, "2:00"),
            e("MERCOLEDÌ", "Stacchi rumeni manubri", "7-9", 3, "FEMORALI / GLUTEI", "Catena posteriore", .hamstrings, "2:30"),
            e("MERCOLEDÌ", "Leg Curl seduto", "12 RM", 2, "FEMORALI", "Femorali", .hamstrings, "1:30"),
            e("MERCOLEDÌ", "Arm Curl", "10 RM", 3, "BICIPITI", "Bicipite", .biceps, "1:30"),
            e("MERCOLEDÌ", "French Press manubri", "10 RM", 3, "TRICIPITI", "Tricipite", .triceps, "1:30")
        ]
    }
}
