import Foundation
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var selectedDay = "LUNEDÌ"
    @Published var exercises: [Exercise] = []
    @Published var scheduleMode: ScheduleMode = .weekdays
    @Published var repetitionMode: RepetitionMode = .general
    @Published var trainingDayCount: Int = 1

    private let weekdayNames = ["LUNEDÌ","MARTEDÌ","MERCOLEDÌ","GIOVEDÌ","VENERDÌ","SABATO","DOMENICA"]
    private var sequenceToWeekday: [String: String] = [:]
    private let key = GymShared.workoutsKey
    private let legacyKey = GymShared.legacyKey
    private let settingsKey = "gymapp.settings.v2"
    private let sequenceMapKey = "gymapp.sequenceMap.v1"

    var days: [String] {
        switch scheduleMode {
        case .weekdays:
            return weekdayNames
        case .trainingDays:
            return (1...max(1, min(7, trainingDayCount))).map { "GIORNO \($0)" }
        }
    }

    init() {
        loadSettings()
        load()
        RecoveryNotifications.shared.requestPermission()
        if exercises.isEmpty {
            exercises = Self.initialSchedule()
            if scheduleMode == .trainingDays { switchToTrainingDays() }
            persist()
        } else {
            normalizeScheduleAfterLoad()
            persist()
        }
    }

    var dayExercises: [Exercise] { exercises.filter { $0.day == selectedDay } }
    var totalSets: Int { dayExercises.reduce(0) { $0 + $1.sets.count } }
    var completedSets: Int { dayExercises.reduce(0) { $0 + $1.sets.filter(\.completed).count } }

    func setScheduleMode(_ mode: ScheduleMode) {
        guard mode != scheduleMode else { return }
        if mode == .trainingDays { switchToTrainingDays() }
        else { switchToWeekdays() }
        scheduleMode = mode
        if !days.contains(selectedDay) { selectedDay = days.first ?? weekdayNames[0] }
        saveSettings()
        persist()
    }

    func setTrainingDayCount(_ count: Int) {
        let newCount = max(1, min(7, count))
        if scheduleMode == .trainingDays {
            let oldCount = trainingDayCount
            trainingDayCount = newCount
            if newCount < oldCount {
                // Non cancelliamo esercizi: se un giorno viene ridotto, lo riportiamo
                // al giorno precedente disponibile invece di perderlo.
                for i in exercises.indices {
                    if let n = sequenceNumber(exercises[i].day), n > newCount {
                        exercises[i].day = "GIORNO \(newCount)"
                    }
                }
            }
            if !days.contains(selectedDay) { selectedDay = days.last ?? "GIORNO 1" }
        } else {
            trainingDayCount = newCount
        }
        saveSettings(); persist()
    }

    func setRepetitionMode(_ mode: RepetitionMode) {
        guard mode != repetitionMode else { return }
        if mode == .general {
            // Mantieni come generale la prima prescrizione disponibile.
            for i in exercises.indices {
                if let first = exercises[i].sets.compactMap(\.prescribedReps).first, !first.isEmpty {
                    exercises[i].targetReps = first
                }
            }
        } else {
            // Quando si passa a per-serie, copia la prescrizione generale in ogni serie
            // che non ne ha ancora una. Nessun peso/reps effettive viene cancellato.
            for i in exercises.indices {
                for j in exercises[i].sets.indices where exercises[i].sets[j].prescribedReps == nil {
                    exercises[i].sets[j].prescribedReps = exercises[i].targetReps
                }
            }
        }
        repetitionMode = mode
        saveSettings(); persist()
    }

    func updateWeight(_ weight: Double, exerciseID: UUID, setID: UUID, saveHistory: Bool = true) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }),
              let si = exercises[ei].sets.firstIndex(where: { $0.id == setID }) else { return }
        if exercises[ei].sets[si].isBackOff { return }
        let old = exercises[ei].sets[si].weight
        guard weight > 0 else { return }
        exercises[ei].sets[si].weight = weight
        if saveHistory && old != weight {
            exercises[ei].sets[si].history.append(WeightLog(weight: weight))
        }
        refreshBackOff(ei)
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
            let source = exercises[ei].sets.last ?? WorkoutSet(weight: 20)
            let backOff = WorkoutSet(reps: source.reps, weight: roundedBackOff(source.weight), isBackOff: true,
                                     prescribedReps: source.prescribedReps)
            exercises[ei].sets.append(backOff)
            exercises[ei].backOffEnabled = true
            refreshBackOff(ei); persist()
        } else {
            guard exercises[ei].backOffEnabled else { return }
            if let removed = exercises[ei].sets.popLast() { RecoveryNotifications.shared.cancel(for: removed.id) }
            exercises[ei].backOffEnabled = false; persist()
        }
    }

    private func roundedBackOff(_ weight: Double) -> Double { weight > 0 ? (weight * 0.8 * 2).rounded() / 2 : 0 }

    private func refreshBackOff(_ exerciseIndex: Int) {
        guard exercises.indices.contains(exerciseIndex), exercises[exerciseIndex].backOffEnabled, exercises[exerciseIndex].sets.count >= 2 else { return }
        let previousIndex = exercises[exerciseIndex].sets.count - 2
        let previous = exercises[exerciseIndex].sets[previousIndex]
        let backIndex = exercises[exerciseIndex].sets.count - 1
        exercises[exerciseIndex].sets[backIndex].weight = roundedBackOff(previous.weight)
        exercises[exerciseIndex].sets[backIndex].prescribedReps = previous.prescribedReps
        exercises[exerciseIndex].sets[backIndex].completed = false
        exercises[exerciseIndex].sets[backIndex].completedAt = nil
        exercises[exerciseIndex].sets[backIndex].isBackOff = true
    }

    func saveWeightHistory(weight: Double, exerciseID: UUID, setID: UUID) { updateWeight(weight, exerciseID: exerciseID, setID: setID) }

    func setTargetReps(_ reps: String, exerciseID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let value = reps.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        exercises[ei].targetReps = value
        if repetitionMode == .perSet {
            for si in exercises[ei].sets.indices where exercises[ei].sets[si].prescribedReps == nil {
                exercises[ei].sets[si].prescribedReps = value
            }
        }
        persist()
    }

    func setReps(_ reps: String, exerciseID: UUID, setID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }), let si = exercises[ei].sets.firstIndex(where: { $0.id == setID }) else { return }
        exercises[ei].sets[si].reps = reps.filter(\.isNumber).prefix(3).description
        persist()
    }

    func toggle(_ exerciseID: UUID, setID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }), let si = exercises[ei].sets.firstIndex(where: { $0.id == setID }) else { return }
        let willComplete = !exercises[ei].sets[si].completed
        if willComplete {
            if exercises[ei].sets[si].weight <= 0 { return }
            if exercises[ei].sets[si].reps.isEmpty {
                exercises[ei].sets[si].reps = effectiveReps(for: exercises[ei], setIndex: si)
            }
            guard Int(exercises[ei].sets[si].reps) ?? 0 > 0 else { return }
            exercises[ei].sets[si].completedAt = Date()
        } else {
            exercises[ei].sets[si].completedAt = nil
        }
        exercises[ei].sets[si].completed = willComplete
        persist()
        let exercise = exercises[ei]
        if willComplete {
            let recovery = exercise.recovery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "2:00" : exercise.recovery
            RecoveryNotifications.shared.start(for: setID, exerciseName: exercise.name, recovery: recovery)
        } else {
            RecoveryNotifications.shared.cancel(for: setID)
        }
    }

    func effectiveReps(for exercise: Exercise, setIndex: Int) -> String {
        if let value = exercise.sets[safe: setIndex]?.reps, let n = Int(value), n > 0 { return value }
        let prescribed: String
        if repetitionMode == .perSet { prescribed = exercise.sets[safe: setIndex]?.prescribedReps ?? exercise.targetReps }
        else { prescribed = exercise.targetReps }
        return Self.lowerBoundReps(prescribed)
    }

    private static func lowerBoundReps(_ value: String) -> String {
        let normalized = value.replacingOccurrences(of: ",", with: ".")
        let firstPart = normalized.split(separator: "-").first.map(String.init) ?? normalized
        let digits = firstPart.filter(\.isNumber)
        if let n = Int(digits), n > 0 { return "\(n)" }
        return "1"
    }

    func addSet(to exerciseID: UUID) {
        guard let i = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        if exercises[i].backOffEnabled, let backOff = exercises[i].sets.popLast() {
            let source = exercises[i].sets.last ?? WorkoutSet(weight: 20)
            var newNormal = WorkoutSet(weight: source.weight)
            newNormal.prescribedReps = repetitionMode == .perSet ? source.prescribedReps : nil
            exercises[i].sets.append(newNormal)
            var newBack = backOff
            newBack.completed = false; newBack.completedAt = nil; newBack.isBackOff = true
            exercises[i].sets.append(newBack)
            refreshBackOff(i)
        } else {
            let source = exercises[i].sets.last ?? WorkoutSet(weight: 20)
            var newSet = WorkoutSet(weight: source.weight)
            newSet.prescribedReps = repetitionMode == .perSet ? source.prescribedReps : nil
            exercises[i].sets.append(newSet)
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
        refreshBackOff(i); persist()
    }

    func setRecovery(_ recovery: String, exerciseID: UUID) {
        guard let i = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[i].recovery = recovery; persist()
    }

    func moveExercise(_ exerciseID: UUID, day: String) {
        guard days.contains(day), let i = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[i].day = day; persist()
    }

    func addExercise(day: String, name: String, reps: String, weights: [Double], recovery: String = "", backOffEnabled: Bool = false,
                     manualTarget: MuscleTarget? = nil, perSetReps: [String]? = nil) {
        let r = ExerciseRecognizer.recognize(name)
        let target = manualTarget ?? r.target
        let group = manualTarget == nil ? r.group : target.title
        let focus = manualTarget == nil ? r.focus : "Focus: \(target.title) · Inserito manualmente"
        let regularWeights = weights.isEmpty ? [20] : weights.map { $0 > 0 ? $0 : 20 }
        var e = Exercise(day: day, name: name, group: group, focus: focus, target: target, reps: reps,
                         numberOfSets: regularWeights.count, recovery: recovery, backOffEnabled: false,
                         perSetReps: repetitionMode == .perSet ? perSetReps : nil)
        e.sets = regularWeights.enumerated().map { index, weight in
            WorkoutSet(weight: weight, prescribedReps: repetitionMode == .perSet ? (perSetReps?[safe: index] ?? reps) : nil)
        }
        if backOffEnabled {
            let source = e.sets.last ?? WorkoutSet(weight: 20)
            e.sets.append(WorkoutSet(weight: roundedBackOff(source.weight), isBackOff: true, prescribedReps: source.prescribedReps))
            e.backOffEnabled = true
        }
        exercises.append(e)
        selectedDay = day
        persist()
    }

    func remove(_ exercise: Exercise) { exercises.removeAll { $0.id == exercise.id }; persist() }

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

    func history(for exercise: Exercise) -> [WeightLog] { exercise.sets.flatMap(\.history).sorted { $0.date < $1.date } }
    func latestWeight(for exercise: Exercise) -> Double { history(for: exercise).last?.weight ?? exercise.sets.map(\.weight).max() ?? 0 }
    func maxWeight(for exercise: Exercise) -> Double { max(history(for: exercise).map(\.weight).max() ?? 0, exercise.sets.map(\.weight).max() ?? 0) }
    func persistChanges() { persist() }

    private func persist() {
        guard let data = try? JSONEncoder().encode(exercises) else { return }
        UserDefaults.standard.set(data, forKey: key)
        GymShared.defaults()?.set(data, forKey: key)
        saveSettings()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func load() {
        let standard = UserDefaults.standard.data(forKey: key) ?? UserDefaults.standard.data(forKey: legacyKey)
        let shared = GymShared.defaults()?.data(forKey: key) ?? GymShared.defaults()?.data(forKey: legacyKey)
        guard let data = standard ?? shared, let decoded = try? JSONDecoder().decode([Exercise].self, from: data) else { return }
        var migrated = decoded

        // Ripara i dati creati dalle versioni precedenti in cui peso e reps
        // potevano finire nei due campi invertiti. Lo stato impossibile è
        // "peso = 0" con un numero positivo nel campo reps: in quel caso il
        // numero inserito era il peso. Spostiamo quindi quel valore nel peso
        // e ricaviamo le reps effettive dal target, senza toccare le serie
        // già corrette. È una migrazione una tantum perché dopo il salvataggio
        // il peso non è più 0.
        for i in migrated.indices {
            for j in migrated[i].sets.indices {
                guard migrated[i].sets[j].weight <= 0,
                      let misplacedWeight = Double(migrated[i].sets[j].reps),
                      misplacedWeight > 0 else { continue }

                migrated[i].sets[j].weight = misplacedWeight
                migrated[i].sets[j].reps = Self.lowerBoundReps(migrated[i].sets[j].prescribedReps ?? migrated[i].targetReps)
                if migrated[i].sets[j].history.isEmpty {
                    migrated[i].sets[j].history = [WeightLog(weight: misplacedWeight)]
                }
            }

            // Vecchio back-off: se l'ultima serie non era marcata, non cancelliamo dati.
            if migrated[i].backOffEnabled, let last = migrated[i].sets.last, !last.isBackOff {
                migrated[i].backOffEnabled = false
            }
        }
        exercises = migrated
    }

    private func loadSettings() {
        let settingsData = GymShared.defaults()?.data(forKey: settingsKey) ?? UserDefaults.standard.data(forKey: settingsKey)
        if let data = settingsData,
           let settings = try? JSONDecoder().decode(SettingsPayload.self, from: data) {
            scheduleMode = settings.scheduleMode
            repetitionMode = settings.repetitionMode
            trainingDayCount = max(1, min(7, settings.trainingDayCount))
        }
        if let map = (GymShared.defaults()?.dictionary(forKey: sequenceMapKey) as? [String: String]) ?? (UserDefaults.standard.dictionary(forKey: sequenceMapKey) as? [String: String]) { sequenceToWeekday = map }
    }

    private func saveSettings() {
        let payload = SettingsPayload(scheduleMode: scheduleMode, repetitionMode: repetitionMode, trainingDayCount: trainingDayCount)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: settingsKey)
            GymShared.defaults()?.set(data, forKey: settingsKey)
        }
        UserDefaults.standard.set(sequenceToWeekday, forKey: sequenceMapKey)
        GymShared.defaults()?.set(sequenceToWeekday, forKey: sequenceMapKey)
    }

    private struct SettingsPayload: Codable {
        let scheduleMode: ScheduleMode
        let repetitionMode: RepetitionMode
        let trainingDayCount: Int
    }

    private func normalizeScheduleAfterLoad() {
        if scheduleMode == .trainingDays {
            if sequenceToWeekday.isEmpty {
                let active = weekdayNames.filter { day in exercises.contains { $0.day == day } }
                trainingDayCount = max(1, min(7, active.count))
                sequenceToWeekday = Dictionary(uniqueKeysWithValues: active.enumerated().map { ("GIORNO \($0.offset + 1)", $0.element) })
                for i in exercises.indices {
                    if let n = active.firstIndex(of: exercises[i].day) { exercises[i].day = "GIORNO \(n + 1)" }
                }
            }
            if !days.contains(selectedDay) { selectedDay = days.first ?? "GIORNO 1" }
        } else if !weekdayNames.contains(selectedDay) {
            selectedDay = weekdayNames.first ?? "LUNEDÌ"
        }
    }

    private func switchToTrainingDays() {
        let active = weekdayNames.filter { day in exercises.contains { $0.day == day } }
        trainingDayCount = max(1, min(7, active.isEmpty ? 1 : active.count))
        sequenceToWeekday = Dictionary(uniqueKeysWithValues: active.enumerated().map { ("GIORNO \($0.offset + 1)", $0.element) })
        let oldSelected = selectedDay
        for i in exercises.indices {
            if let n = active.firstIndex(of: exercises[i].day) { exercises[i].day = "GIORNO \(n + 1)" }
        }
        selectedDay = active.firstIndex(of: oldSelected).map { "GIORNO \($0 + 1)" } ?? days.first ?? "GIORNO 1"
    }

    private func switchToWeekdays() {
        for i in exercises.indices {
            if let weekday = sequenceToWeekday[exercises[i].day] { exercises[i].day = weekday }
        }
        if let weekday = sequenceToWeekday[selectedDay] { selectedDay = weekday }
        else if !weekdayNames.contains(selectedDay) { selectedDay = weekdayNames.first ?? "LUNEDÌ" }
    }

    private func sequenceNumber(_ value: String) -> Int? {
        Int(value.replacingOccurrences(of: "GIORNO ", with: ""))
    }

    private static func initialSchedule() -> [Exercise] {
        func e(_ d:String,_ n:String,_ r:String,_ s:Int,_ g:String,_ f:String,_ t:MuscleTarget,_ rec:String)->Exercise {
            Exercise(day:d,name:n,group:g,focus:f,target:t,reps:r,numberOfSets:s,recovery:rec)
        }
        return [
            e("LUNEDÌ","Spinte manubri panca 32","7-9",3,"PETTO (ALTO)","Pettorali superiori e tricipiti",.chest,"2:00"),
            e("LUNEDÌ","Lat Pulldown","7-9",3,"DORSO","Gran dorsale e bicipiti",.back,"2:00"),
            e("LUNEDÌ","Chest Press","8-10",3,"PETTO","Pettorali e tricipiti",.chest,"2:00"),
            e("LUNEDÌ","T-Bar prona larga","8-10",3,"DORSO","Dorsali e parte alta della schiena",.back,"2:00"),
            e("LUNEDÌ","Alzate laterali","10-12",4,"SPALLE","Deltoide laterale",.shoulders,"1:30"),
            e("LUNEDÌ","Push Down asta curva","10 RM",4,"TRICIPITI","Tricipite",.triceps,"1:30"),
            e("LUNEDÌ","Curl cavo basso","10 RM",4,"BICIPITI","Bicipite",.biceps,"1:30"),
            e("MARTEDÌ","Leg Extension","12 RM",4,"QUADRICIPITI","Quadricipite",.quads,"1:30"),
            e("MARTEDÌ","Leg Press 45","7-9",3,"GAMBE","Quadricipiti e glutei",.quads,"2:00"),
            e("MARTEDÌ","Leg Curl sdraiato","10-12",2,"FEMORALI","Femorali",.hamstrings,"1:30"),
            e("MARTEDÌ","Adduttori","10-12",2,"ADDUTTORI","Adduttori",.quads,"1:30"),
            e("MARTEDÌ","Calf Machine","8-10",4,"POLPACCI","Polpacci",.hamstrings,"1:30"),
            e("MERCOLEDÌ","Panca piana bilanciere","7-9",4,"PETTO","Pettorali e tricipiti",.chest,"2:30"),
            e("MERCOLEDÌ","Rematore bilanciere","7-9",3,"DORSO","Dorsali e parte alta della schiena",.back,"2:00"),
            e("MERCOLEDÌ","Lento avanti manubri panca 71","8-10",3,"SPALLE","Deltoidi e tricipiti",.shoulders,"2:00"),
            e("MERCOLEDÌ","Rowing","8-10",3,"DORSO","Schiena",.back,"2:00"),
            e("MERCOLEDÌ","Stacchi rumeni manubri","7-9",3,"FEMORALI / GLUTEI","Catena posteriore",.hamstrings,"2:30"),
            e("MERCOLEDÌ","Leg Curl seduto","12 RM",2,"FEMORALI","Femorali",.hamstrings,"1:30"),
            e("MERCOLEDÌ","Arm Curl","10 RM",3,"BICIPITI","Bicipite",.biceps,"1:30"),
            e("MERCOLEDÌ","French Press manubri","10 RM",3,"TRICIPITI","Tricipite",.triceps,"1:30")
        ]
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? { indices.contains(index) ? self[index] : nil }
}
