import Foundation
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

enum WorkoutDayStatus: String {
    case rest
    case notStarted
    case inProgress
    case completed

    var title: String {
        switch self {
        case .rest: return "RIPOSO"
        case .notStarted: return "NON INIZIATO"
        case .inProgress: return "IN CORSO"
        case .completed: return "COMPLETATO"
        }
    }

    var symbol: String {
        switch self {
        case .rest: return "—"
        case .notStarted: return "○"
        case .inProgress: return "🟡"
        case .completed: return "✓"
        }
    }
}

struct WorkoutDaySummary: Identifiable {
    let id: String
    let date: Date
    let day: String
    let exerciseCount: Int
    let totalSets: Int
    let completedSets: Int
    let status: WorkoutDayStatus

    var progress: Double {
        totalSets > 0 ? Double(completedSets) / Double(totalSets) : 0
    }
}

struct WorkoutWeekSummary {
    let startDate: Date
    let endDate: Date
    let days: [WorkoutDaySummary]

    var workoutDays: Int { days.filter { $0.status != .rest }.count }
    var completedWorkoutDays: Int { days.filter { $0.status == .completed }.count }
    var totalSets: Int { days.reduce(0) { $0 + $1.totalSets } }
    var completedSets: Int { days.reduce(0) { $0 + $1.completedSets } }
    var progress: Double { totalSets > 0 ? Double(completedSets) / Double(totalSets) : 0 }
}

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var selectedDay = "LUNEDÌ"
    @Published var exercises: [Exercise] = []

<<<<<<< HEAD
    /// Settimana completa: la scheda può avere esercizi anche nel weekend, ma un giorno
    /// senza esercizi viene mostrato esplicitamente come RIPOSO.
    let days = ["LUNEDÌ", "MARTEDÌ", "MERCOLEDÌ", "GIOVEDÌ", "VENERDÌ", "SABATO", "DOMENICA"]
=======
    let days = ["LUNEDÌ", "MARTEDÌ", "MERCOLEDÌ", "GIOVEDÌ", "VENERDÌ"]
>>>>>>> 64db72c976aea6b5e22d79ff3e9612b3216459a7

    private let key = GymShared.workoutsKey
    private let legacyKey = GymShared.legacyKey

    init() {
        load()
        RecoveryNotifications.shared.requestPermission()
        if exercises.isEmpty {
            exercises = Self.initialSchedule()
            persist()
        } else {
            prepareDayForToday(selectedDay)
        }
    }

    var dayExercises: [Exercise] { exercises.filter { $0.day == selectedDay } }
    var totalSets: Int { dayExercises.reduce(0) { $0 + $1.sets.count } }
    /// Serie realmente completate nella giornata odierna, non semplicemente compilate.
    var completedSets: Int {
        dayExercises.reduce(0) { total, exercise in
            total + (todaySession(for: exercise)?.sets.count ?? 0)
        }
    }

    // MARK: - Serie

    // MARK: - Serie

    func updateWeight(_ weight: Double, exerciseID: UUID, setID: UUID, saveHistory: Bool = true) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }),
              let si = exercises[ei].sets.firstIndex(where: { $0.id == setID }) else { return }

        // Il back-off automatico resta derivato dalla serie precedente.
        if exercises[ei].backOffEnabled && si == exercises[ei].sets.count - 1 { return }

        let safeWeight = max(0, weight)
        let old = exercises[ei].sets[si].weight
        exercises[ei].sets[si].weight = safeWeight

        if saveHistory && old != safeWeight {
            exercises[ei].sets[si].history.append(WeightLog(weight: safeWeight))
        }

        refreshBackOff(ei)
        updateTodaySession(forExerciseAt: ei)
        persist()
    }

    func weight(exerciseID: UUID, setIndex: Int) -> Double {
        guard let exercise = exercises.first(where: { $0.id == exerciseID }),
              exercise.sets.indices.contains(setIndex) else { return 0 }
        return exercise.sets[setIndex].weight
    }

    /// Peso del back-off: 80% della serie normale precedente, arrotondato a 0,5 kg.
    func backOffWeight(exerciseID: UUID) -> Double {
        guard let exercise = exercises.first(where: { $0.id == exerciseID }),
              exercise.backOffEnabled,
              exercise.sets.count >= 2 else { return 0 }
        let previous = exercise.sets[exercise.sets.count - 2].weight
        return roundedBackOff(previous)
    }

    func setBackOffEnabled(_ enabled: Bool, exerciseID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }

        if enabled {
            guard !exercises[ei].backOffEnabled else { return }
            let source = exercises[ei].sets.last ?? WorkoutSet(reps: "")
            var backOff = WorkoutSet(
                reps: "",
                weight: roundedBackOff(source.weight),
                isBackOff: true
            )
            backOff.completed = false
            exercises[ei].sets.append(backOff)
            exercises[ei].backOffEnabled = true
            refreshBackOff(ei)
        } else {
            guard exercises[ei].backOffEnabled else { return }
            if let removed = exercises[ei].sets.popLast() {
                RecoveryNotifications.shared.cancel(for: removed.id)
            }
            exercises[ei].backOffEnabled = false
        }

        updateTodaySession(forExerciseAt: ei)
        persist()
    }

    private func roundedBackOff(_ weight: Double) -> Double {
        guard weight > 0 else { return 0 }
        return (weight * 0.8 * 2).rounded() / 2
    }

    private func refreshBackOff(_ exerciseIndex: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].backOffEnabled,
              exercises[exerciseIndex].sets.count >= 2 else { return }

        let previousIndex = exercises[exerciseIndex].sets.count - 2
        let previous = exercises[exerciseIndex].sets[previousIndex]
        let backOffIndex = exercises[exerciseIndex].sets.count - 1

        exercises[exerciseIndex].sets[backOffIndex].weight = roundedBackOff(previous.weight)
        // Le reps del back-off sono libere: non copiamo il valore della serie normale.
        exercises[exerciseIndex].sets[backOffIndex].isBackOff = true
    }

    func saveWeightHistory(weight: Double, exerciseID: UUID, setID: UUID) {
        updateWeight(weight, exerciseID: exerciseID, setID: setID, saveHistory: true)
    }

    func setReps(_ reps: String, exerciseID: UUID, setID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }),
              let si = exercises[ei].sets.firstIndex(where: { $0.id == setID }) else { return }

        // Le ripetizioni effettive sono un dato numerico. Durante la digitazione
        // è consentito lasciare il campo vuoto; una serie vuota non può però essere completata.
        let filtered = reps.filter { $0.isNumber }
        exercises[ei].sets[si].reps = String(filtered.prefix(3))
        updateTodaySession(forExerciseAt: ei)
        persist()
    }

    func setRecovery(_ recovery: String, exerciseID: UUID) {
        guard let i = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[i].recovery = recovery
        persist()
    }

    func toggle(_ exerciseID: UUID, setID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }),
              let si = exercises[ei].sets.firstIndex(where: { $0.id == setID }) else { return }

        let set = exercises[ei].sets[si]
        let actualReps = Int(set.reps.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard !set.completed || actualReps > 0 else { return }

        let willComplete = !set.completed
        exercises[ei].sets[si].completed = willComplete
<<<<<<< HEAD
        exercises[ei].sets[si].completedAt = willComplete ? Date() : nil
=======
>>>>>>> 64db72c976aea6b5e22d79ff3e9612b3216459a7
        updateTodaySession(forExerciseAt: ei)
        persist()

        let exercise = exercises[ei]
        if willComplete {
            let recovery = exercise.recovery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "2:00" : exercise.recovery
            RecoveryNotifications.shared.start(for: setID, exerciseName: exercise.name, recovery: recovery)
        } else {
            RecoveryNotifications.shared.cancel(for: setID)
        }
    }

    func addSet(to exerciseID: UUID) {
        guard let i = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }

        if exercises[i].backOffEnabled, let oldBackOff = exercises[i].sets.popLast() {
            RecoveryNotifications.shared.cancel(for: oldBackOff.id)
            let source = exercises[i].sets.last ?? WorkoutSet(reps: "", weight: 20)
            exercises[i].sets.append(WorkoutSet(reps: "", weight: source.weight))
        } else {
            let source = exercises[i].sets.last ?? WorkoutSet(reps: "", weight: 20)
            exercises[i].sets.append(WorkoutSet(reps: "", weight: source.weight))
        }

        // Ricostruisce il back-off come ultima serie senza modificare gli ID delle serie esistenti.
        if exercises[i].backOffEnabled {
            let last = WorkoutSet(
                reps: "",
                weight: roundedBackOff(exercises[i].sets[exercises[i].sets.count - 1].weight),
                isBackOff: true
            )
            exercises[i].sets.append(last)
            refreshBackOff(i)
        }

        persist()
    }

    func removeSet(from exerciseID: UUID) {
        guard let i = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }

        let minimumRegularSets = 1
        let regularCount = exercises[i].backOffEnabled ? exercises[i].sets.count - 1 : exercises[i].sets.count
        guard regularCount > minimumRegularSets else { return }

        let index = exercises[i].backOffEnabled ? exercises[i].sets.count - 2 : exercises[i].sets.count - 1
        let removed = exercises[i].sets.remove(at: index)
        RecoveryNotifications.shared.cancel(for: removed.id)
        refreshBackOff(i)
        updateTodaySession(forExerciseAt: i)
        persist()
    }

    // MARK: - Esercizi / scheda

    func moveExercise(_ exerciseID: UUID, day: String) {
        guard let i = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[i].day = day
        persist()
    }

    func addExercise(
        day: String,
        name: String,
        reps: String,
        weights: [Double],
        recovery: String = "",
        backOffEnabled: Bool = false,
        manualTarget: MuscleTarget? = nil
    ) {
        let r = ExerciseRecognizer.recognize(name)
        let target = manualTarget ?? r.target
        let group = manualTarget == nil ? r.group : target.title
        let focus = manualTarget == nil ? r.focus : "Focus: \(target.title) · Inserito manualmente"
        let regularWeights = weights.isEmpty ? [20] : weights

        var exercise = Exercise(
            day: day,
            name: name,
            group: group,
            focus: focus,
            target: target,
            reps: reps,
            numberOfSets: regularWeights.count,
            recovery: recovery,
            backOffEnabled: false
        )
        exercise.sets = regularWeights.map { WorkoutSet(reps: "", weight: max(0, $0)) }

        if backOffEnabled {
            exercise.backOffEnabled = true
            exercise.sets.append(WorkoutSet(reps: "", weight: roundedBackOff(exercise.sets.last?.weight ?? 0), isBackOff: true))
        }

        exercises.append(exercise)
        selectedDay = day
        persist()
    }

    func addImported(_ item: ImportedExercise, weights: [Double]? = nil) {
        let ws = weights ?? Array(repeating: 20, count: max(1, item.sets))
        addExercise(day: item.day, name: item.name, reps: item.reps, weights: ws, recovery: item.recovery)
    }

    func remove(_ exercise: Exercise) {
        for set in exercise.sets {
            RecoveryNotifications.shared.cancel(for: set.id)
        }
        exercises.removeAll { $0.id == exercise.id }
        persist()
    }

    func resetDay() {
        for i in exercises.indices where exercises[i].day == selectedDay {
            for j in exercises[i].sets.indices {
                exercises[i].sets[j].completed = false
                RecoveryNotifications.shared.cancel(for: exercises[i].sets[j].id)
            }
            removeTodaySession(forExerciseAt: i)
        }
        persist()
    }

    // MARK: - Storico peso legacy

    func history(for exercise: Exercise) -> [WeightLog] {
        exercise.sets.flatMap { $0.history }.sorted { $0.date < $1.date }
    }

    func latestWeight(for exercise: Exercise) -> Double {
        history(for: exercise).last?.weight ?? exercise.sets.map(\.weight).max() ?? 0
    }

    func maxWeight(for exercise: Exercise) -> Double {
        max(history(for: exercise).map(\.weight).max() ?? 0, exercise.sets.map(\.weight).max() ?? 0)
    }

    // MARK: - Storico sessioni / performance

    func sessions(for exercise: Exercise) -> [ExerciseSession] {
        exercise.sessions.sorted { $0.date < $1.date }
    }

    func latestSession(for exercise: Exercise) -> ExerciseSession? {
        sessions(for: exercise).last
    }

    /// L'ultima sessione precedente a oggi. È quella mostrata nella scheda durante l'allenamento.
    func previousSession(for exercise: Exercise, referenceDate: Date = Date()) -> ExerciseSession? {
        let calendar = Calendar.current
        return sessions(for: exercise)
            .filter { !calendar.isDate($0.date, inSameDayAs: referenceDate) }
            .last
    }

    func todaySession(for exercise: Exercise, referenceDate: Date = Date()) -> ExerciseSession? {
        let calendar = Calendar.current
        return sessions(for: exercise).first { calendar.isDate($0.date, inSameDayAs: referenceDate) }
    }

    func performance(for exercise: Exercise, referenceDate: Date = Date()) -> PerformanceComparison? {
        guard let current = todaySession(for: exercise, referenceDate: referenceDate),
              let previous = previousSession(for: exercise, referenceDate: referenceDate),
              !current.sets.isEmpty,
              !previous.sets.isEmpty,
              current.sets.count >= previous.sets.count else { return nil }

        let currentByIndex = Dictionary(uniqueKeysWithValues: current.sets.map { ($0.setIndex, $0) })
        let previousByIndex = Dictionary(uniqueKeysWithValues: previous.sets.map { ($0.setIndex, $0) })
        let commonIndexes = Set(currentByIndex.keys).intersection(previousByIndex.keys).sorted()

        guard !commonIndexes.isEmpty else { return nil }

        var comparisons: [SetPerformanceComparison] = []
        for index in commonIndexes {
            guard let now = currentByIndex[index], let before = previousByIndex[index] else { continue }
            let oldScore = before.volume
            let newScore = now.volume
            let delta = oldScore > 0 ? (newScore - oldScore) / oldScore : (newScore > 0 ? 1 : 0)
            comparisons.append(
                SetPerformanceComparison(
                    setIndex: index,
                    previousWeight: before.weight,
                    previousReps: before.reps,
                    currentWeight: now.weight,
                    currentReps: now.reps,
                    volumeDeltaRatio: delta
                )
            )
        }

        guard !comparisons.isEmpty else { return nil }

        let previousVolume = comparisons.reduce(0) { $0 + ($1.previousWeight * Double($1.previousReps)) }
        let currentVolume = comparisons.reduce(0) { $0 + ($1.currentWeight * Double($1.currentReps)) }
        let averageDelta = previousVolume > 0 ? (currentVolume - previousVolume) / previousVolume : 0

        let improvedSets = comparisons.filter { $0.volumeDeltaRatio > 0.03 }.count
        let worsenedSets = comparisons.filter { $0.volumeDeltaRatio < -0.05 }.count
        let tolerance = 0.03

        let status: PerformanceStatus
        if averageDelta >= tolerance || improvedSets > worsenedSets && improvedSets >= max(1, comparisons.count / 2) {
            status = .progress
        } else if averageDelta <= -0.05 && worsenedSets > improvedSets {
            status = .decline
        } else {
            status = .maintain
        }

        return PerformanceComparison(
            status: status,
            previousDate: previous.date,
            currentDate: current.date,
            previousVolume: previousVolume,
            currentVolume: currentVolume,
            volumeDeltaRatio: averageDelta,
            sets: comparisons
        )
    }

    func totalVolume(for exercise: Exercise) -> Double {
        sessions(for: exercise).reduce(0) { $0 + $1.volume }
    }

    func todayVolume(for exercise: Exercise) -> Double {
        todaySession(for: exercise)?.volume ?? 0
    }

    func weeklyVolume(for target: MuscleTarget, referenceDate: Date = Date()) -> Double {
<<<<<<< HEAD
        let calendar = Calendar.current
        let start = startOfWeek(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? referenceDate
        return exercises
            .filter { $0.target == target }
            .flatMap { $0.sessions }
            .filter { $0.date >= start && $0.date < end }
=======
        guard let start = Calendar.current.date(byAdding: .day, value: -6, to: referenceDate) else { return 0 }
        return exercises
            .filter { $0.target == target }
            .flatMap { $0.sessions }
            .filter { $0.date >= start && $0.date <= referenceDate }
>>>>>>> 64db72c976aea6b5e22d79ff3e9612b3216459a7
            .reduce(0) { $0 + $1.volume }
    }

    private func updateTodaySession(forExerciseAt index: Int, date: Date = Date()) {
        guard exercises.indices.contains(index) else { return }

        let records: [SessionSetRecord] = exercises[index].sets.enumerated().compactMap { offset, set in
            guard set.completed,
                  let reps = Int(set.reps.trimmingCharacters(in: .whitespacesAndNewlines)),
                  reps > 0 else { return nil }
            return SessionSetRecord(
                id: set.id,
                setIndex: offset,
                weight: set.weight,
                reps: reps,
<<<<<<< HEAD
                isBackOff: set.isBackOff,
                completedAt: set.completedAt ?? date
=======
                isBackOff: set.isBackOff
>>>>>>> 64db72c976aea6b5e22d79ff3e9612b3216459a7
            )
        }

        let calendar = Calendar.current
        if let existingIndex = exercises[index].sessions.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            if records.isEmpty {
                exercises[index].sessions.remove(at: existingIndex)
            } else {
                exercises[index].sessions[existingIndex].sets = records
            }
        } else if !records.isEmpty {
            exercises[index].sessions.append(ExerciseSession(date: date, sets: records))
        }

        exercises[index].sessions.sort { $0.date < $1.date }
    }

    private func removeTodaySession(forExerciseAt index: Int) {
        guard exercises.indices.contains(index) else { return }
        let calendar = Calendar.current
        exercises[index].sessions.removeAll { calendar.isDateInToday($0.date) }
    }

<<<<<<< HEAD
    // MARK: - Settimana lunedì → domenica

    func startOfWeek(for date: Date = Date()) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    func weekDates(for date: Date = Date()) -> [Date] {
        let start = startOfWeek(for: date)
        let calendar = Calendar.current
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    func dayName(for date: Date) -> String {
        let index = Calendar.current.component(.weekday, from: date)
        switch index {
        case 2: return "LUNEDÌ"
        case 3: return "MARTEDÌ"
        case 4: return "MERCOLEDÌ"
        case 5: return "GIOVEDÌ"
        case 6: return "VENERDÌ"
        case 7: return "SABATO"
        default: return "DOMENICA"
        }
    }

    func weekTitle(for date: Date = Date()) -> String {
        let dates = weekDates(for: date)
        guard let first = dates.first, let last = dates.last else { return "SETTIMANA" }
        let firstText = first.formatted(.dateTime.day().month(.wide))
        let lastText = last.formatted(.dateTime.day().month(.wide))
        return "SETTIMANA \(firstText) – \(lastText)".uppercased()
    }

    func weekDaySummary(for date: Date) -> WorkoutDaySummary {
        let day = dayName(for: date)
        let dayExercises = exercises.filter { $0.day == day }
        let total = dayExercises.reduce(0) { $0 + $1.sets.count }
        let completed = dayExercises.reduce(0) { total, exercise in
            total + (exercise.sessions.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })?.sets.count ?? 0)
        }
        let status: WorkoutDayStatus
        if dayExercises.isEmpty {
            status = .rest
        } else if completed == 0 {
            status = .notStarted
        } else if completed >= total {
            status = .completed
        } else {
            status = .inProgress
        }

        return WorkoutDaySummary(
            id: "\(day)-\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)",
            date: date,
            day: day,
            exerciseCount: dayExercises.count,
            totalSets: total,
            completedSets: min(completed, total),
            status: status
        )
    }

    func currentWeekSummary(referenceDate: Date = Date()) -> WorkoutWeekSummary {
        let dates = weekDates(for: referenceDate)
        let start = dates.first ?? referenceDate
        let end = dates.last ?? referenceDate
        return WorkoutWeekSummary(startDate: start, endDate: end, days: dates.map { weekDaySummary(for: $0) })
    }

    func historicalWeekSummaries() -> [WorkoutWeekSummary] {
        var starts = Set<Date>()
        starts.insert(startOfWeek())
        for exercise in exercises {
            for session in exercise.sessions {
                starts.insert(startOfWeek(for: session.date))
            }
        }
        return starts.sorted(by: >).map { start in
            let dates = weekDates(for: start)
            return WorkoutWeekSummary(
                startDate: dates.first ?? start,
                endDate: dates.last ?? start,
                days: dates.map { weekDaySummary(for: $0) }
            )
        }
    }

    /// Allinea la UI del giorno selezionato alla sessione reale di oggi.
    /// Così una serie completata la settimana scorsa non rimane spuntata nella nuova settimana.
    func prepareDayForToday(_ day: String) {
        let calendar = Calendar.current
        for i in exercises.indices where exercises[i].day == day {
            let today = exercises[i].sessions.first(where: { calendar.isDateInToday($0.date) })
            let completedIDs = Set(today?.sets.map(\.id) ?? [])
            for j in exercises[i].sets.indices {
                exercises[i].sets[j].completed = completedIDs.contains(exercises[i].sets[j].id)
                if !exercises[i].sets[j].completed {
                    exercises[i].sets[j].completedAt = nil
                }
            }
        }
        persist()
    }

=======
>>>>>>> 64db72c976aea6b5e22d79ff3e9612b3216459a7
    // MARK: - Backup locale

    func backupData() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(exercises)
    }

    @discardableResult
    func importBackup(data: Data) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let imported = try? decoder.decode([Exercise].self, from: data), !imported.isEmpty else {
            return false
        }

        exercises = imported
        if !exercises.contains(where: { $0.day == selectedDay }) {
            selectedDay = days.first(where: { day in exercises.contains(where: { $0.day == day }) }) ?? selectedDay
        }
        persist()
        return true
    }

    func persistChanges() { persist() }

    // MARK: - Persistenza

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

        if let data = standard ?? shared,
           let decoded = try? JSONDecoder().decode([Exercise].self, from: data) {
            var migrated = decoded

            // Migrazione del vecchio back-off che sostituiva l'ultima serie.
            for i in migrated.indices where migrated[i].backOffEnabled {
                if let last = migrated[i].sets.last,
                   !last.isBackOff,
                   migrated[i].sets.count > 1 {
                    migrated[i].sets.removeLast()
                }
                migrated[i].backOffEnabled = false
            }

            // Migrazione del vecchio campo reps: se conteneva il range della scheda,
            // lo spostiamo in targetReps e lasciamo libero il campo delle reps effettive.
            for i in migrated.indices {
                if migrated[i].targetReps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let legacy = migrated[i].sets.first?.reps.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    migrated[i].targetReps = Self.looksLikePrescription(legacy) ? legacy : "8-10"
                }

                if migrated[i].sessions.isEmpty {
                    // I vecchi dati non contenevano snapshot completi di sessione.
                    // Non inventiamo uno storico: verrà creato dal primo allenamento completato.
                }

                for j in migrated[i].sets.indices {
                    let value = migrated[i].sets[j].reps.trimmingCharacters(in: .whitespacesAndNewlines)
                    if Self.looksLikePrescription(value) {
                        migrated[i].sets[j].reps = ""
                    }
                }
            }

            exercises = migrated
            persist()
        }
    }

    private static func looksLikePrescription(_ value: String) -> Bool {
        let normalized = value.uppercased().replacingOccurrences(of: " ", with: "")
        return normalized.contains("RM") || normalized.contains("-") || normalized.contains("×")
    }

    // MARK: - Scheda iniziale

    private static func initialSchedule() -> [Exercise] {
        func e(
            _ d: String,
            _ n: String,
            _ r: String,
            _ s: Int,
            _ g: String,
            _ f: String,
            _ t: MuscleTarget,
            _ rec: String
        ) -> Exercise {
            Exercise(
                day: d,
                name: n,
                group: g,
                focus: f,
                target: t,
                reps: r,
                numberOfSets: s,
                recovery: rec
            )
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

enum PerformanceStatus: String {
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

    var symbol: String {
        switch self {
        case .progress: return "🟢"
        case .maintain: return "🟡"
        case .decline: return "🔴"
        }
    }
}

struct SetPerformanceComparison: Identifiable {
    let id = UUID()
    let setIndex: Int
    let previousWeight: Double
    let previousReps: Int
    let currentWeight: Double
    let currentReps: Int
    let volumeDeltaRatio: Double
}

struct PerformanceComparison {
    let status: PerformanceStatus
    let previousDate: Date
    let currentDate: Date
    let previousVolume: Double
    let currentVolume: Double
    let volumeDeltaRatio: Double
    let sets: [SetPerformanceComparison]
}
