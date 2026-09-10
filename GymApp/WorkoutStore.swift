import Foundation
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var selectedDay = "LUNEDÌ" { didSet { save() } }
    @Published var exercises: [Exercise] = [] { didSet { save() } }
    let days = ["LUNEDÌ","MARTEDÌ","MERCOLEDÌ","GIOVEDÌ","VENERDÌ","SABATO","DOMENICA"]
    private let key = GymShared.workoutsKey
    private let legacyKey = GymShared.legacyKey

    init() {
        load()
        RecoveryNotifications.shared.requestPermission()
        if exercises.isEmpty { exercises = Self.initialSchedule() }
    }
    var dayExercises: [Exercise] { exercises.filter { $0.day == selectedDay } }
    var totalSets: Int { dayExercises.reduce(0) { $0 + $1.sets.count } }
    var completedSets: Int { dayExercises.reduce(0) { $0 + $1.sets.filter(\.completed).count } }

    func updateWeight(_ weight: Double, exerciseID: UUID, setID: UUID, saveHistory: Bool = true) {
        guard let ei = exercises.firstIndex(where: {$0.id == exerciseID}),
              let si = exercises[ei].sets.firstIndex(where: {$0.id == setID}) else { return }
        // Il peso della serie di back-off è calcolato automaticamente e non è modificabile.
        if exercises[ei].backOffEnabled && si == exercises[ei].sets.count - 1 { return }
        let old = exercises[ei].sets[si].weight
        exercises[ei].sets[si].weight = weight
        if saveHistory && old != weight {
            exercises[ei].sets[si].history.append(WeightLog(weight: weight))
        }
        refreshBackOff(ei)
    }

    func weight(exerciseID: UUID, setIndex: Int) -> Double {
        guard let exercise = exercises.first(where: { $0.id == exerciseID }), exercise.sets.indices.contains(setIndex) else { return 0 }
        return exercise.sets[setIndex].weight
    }

    /// Peso del back-off: 20% in meno rispetto all'ultima serie normale (80%).
    func backOffWeight(exerciseID: UUID) -> Double {
        guard let exercise = exercises.first(where: { $0.id == exerciseID }),
              exercise.backOffEnabled, exercise.sets.count >= 2 else { return 0 }
        let previous = exercise.sets[exercise.sets.count - 2].weight
        return roundedBackOff(previous)
    }

    func setBackOffEnabled(_ enabled: Bool, exerciseID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        if enabled {
            guard !exercises[ei].backOffEnabled else { return }
            let source = exercises[ei].sets.last ?? WorkoutSet(reps: "8-10", weight: 20)
            var backOff = WorkoutSet(reps: source.reps, weight: roundedBackOff(source.weight))
            backOff.completed = false
            backOff.isBackOff = true
            // L'attivazione aggiunge una nuova serie esclusivamente per il back-off.
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
        exercises[exerciseIndex].sets[exercises[exerciseIndex].sets.count - 1].weight = roundedBackOff(previous.weight)
        exercises[exerciseIndex].sets[exercises[exerciseIndex].sets.count - 1].reps = previous.reps
        exercises[exerciseIndex].sets[exercises[exerciseIndex].sets.count - 1].completed = false
        exercises[exerciseIndex].sets[exercises[exerciseIndex].sets.count - 1].isBackOff = true
    }

    func saveWeightHistory(weight: Double, exerciseID: UUID, setID: UUID) { updateWeight(weight, exerciseID: exerciseID, setID: setID, saveHistory: true) }

    func toggle(_ exerciseID: UUID, setID: UUID) {
        guard let ei = exercises.firstIndex(where: {$0.id == exerciseID}), let si = exercises[ei].sets.firstIndex(where: {$0.id == setID}) else { return }
        let willComplete = !exercises[ei].sets[si].completed
        exercises[ei].sets[si].completed = willComplete
        let exercise = exercises[ei]
        if willComplete { RecoveryNotifications.shared.start(for: setID, exerciseName: exercise.name, recovery: exercise.recovery) }
        else { RecoveryNotifications.shared.cancel(for: setID) }
    }
    func addSet(to exerciseID: UUID) {
        guard let i = exercises.firstIndex(where: {$0.id == exerciseID}) else { return }
        if exercises[i].backOffEnabled, var backOff = exercises[i].sets.popLast() {
            let source = exercises[i].sets.last ?? WorkoutSet(reps: "8-10", weight: 20)
            exercises[i].sets.append(WorkoutSet(reps: source.reps, weight: source.weight))
            backOff.isBackOff = true
            exercises[i].sets.append(backOff)
            refreshBackOff(i)
        } else {
            let source = exercises[i].sets.last ?? WorkoutSet(reps: "8-10", weight: 20)
            exercises[i].sets.append(WorkoutSet(reps: source.reps, weight: source.weight))
        }
    }

    func removeSet(from exerciseID: UUID) {
        guard let i = exercises.firstIndex(where: {$0.id == exerciseID}) else { return }
        let minimumRegularSets = 1
        let regularCount = exercises[i].backOffEnabled ? exercises[i].sets.count - 1 : exercises[i].sets.count
        guard regularCount > minimumRegularSets else { return }
        let index = exercises[i].backOffEnabled ? exercises[i].sets.count - 2 : exercises[i].sets.count - 1
        let removed = exercises[i].sets.remove(at: index)
        RecoveryNotifications.shared.cancel(for: removed.id)
        refreshBackOff(i)
    }
    func setReps(_ reps: String, exerciseID: UUID, setID: UUID) { guard let ei=exercises.firstIndex(where:{$0.id==exerciseID}), let si=exercises[ei].sets.firstIndex(where:{$0.id==setID}) else{return}; exercises[ei].sets[si].reps=reps }
    func setRecovery(_ recovery: String, exerciseID: UUID) { guard let i=exercises.firstIndex(where:{$0.id==exerciseID}) else{return}; exercises[i].recovery=recovery }
    func moveExercise(_ exerciseID: UUID, day: String) { guard let i=exercises.firstIndex(where:{$0.id==exerciseID}) else{return}; exercises[i].day=day }
    func addExercise(day:String,name:String,reps:String,weights:[Double],recovery:String="",backOffEnabled: Bool = false) {
        let r=ExerciseRecognizer.recognize(name)
        let regularWeights = weights.isEmpty ? [20] : weights
        var e=Exercise(day:day,name:name,group:r.group,focus:r.focus,target:r.target,reps:reps,numberOfSets:regularWeights.count,recovery:recovery,backOffEnabled:backOffEnabled)
        e.sets=regularWeights.map{WorkoutSet(reps:reps,weight:$0)}
        if backOffEnabled {
            let source = e.sets.last ?? WorkoutSet(reps: reps, weight: 20)
            e.sets.append(WorkoutSet(reps: source.reps, weight: roundedBackOff(source.weight), isBackOff: true))
        }
        exercises.append(e)
        selectedDay=day
    }
    func addImported(_ item: ImportedExercise, weights: [Double]? = nil) { let ws = weights ?? Array(repeating: 20, count: max(1,item.sets)); addExercise(day:item.day,name:item.name,reps:item.reps,weights:ws,recovery:item.recovery) }
    func remove(_ exercise: Exercise) { exercises.removeAll{$0.id==exercise.id} }
    func resetDay() { for i in exercises.indices where exercises[i].day==selectedDay { for j in exercises[i].sets.indices { exercises[i].sets[j].completed=false; RecoveryNotifications.shared.cancel(for: exercises[i].sets[j].id) } } }
    func history(for exercise: Exercise)->[WeightLog] { exercise.sets.flatMap{$0.history}.sorted{$0.date<$1.date} }
    func latestWeight(for exercise: Exercise)->Double { history(for:exercise).last?.weight ?? exercise.sets.map(\.weight).max() ?? 0 }
    func maxWeight(for exercise: Exercise)->Double { max(history(for:exercise).map(\.weight).max() ?? 0, exercise.sets.map(\.weight).max() ?? 0) }

    private func save() {
        guard let data=try? JSONEncoder().encode(exercises) else{return}
        UserDefaults.standard.set(data,forKey:key)
        if let shared=GymShared.defaults() { shared.set(data,forKey:key) }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    private func load() {
        let standard = UserDefaults.standard.data(forKey:key) ?? UserDefaults.standard.data(forKey:legacyKey)
        let shared = GymShared.defaults()?.data(forKey:key) ?? GymShared.defaults()?.data(forKey:legacyKey)
        if let data = standard ?? shared, let decoded=try? JSONDecoder().decode([Exercise].self,from:data) {
            var migrated = decoded
            // Migrazione della vecchia implementazione: il vecchio back-off sostituiva l'ultima serie.
            // Lo rimuoviamo una sola volta; con il nuovo pulsante il back-off viene aggiunto come serie separata.
            for i in migrated.indices where migrated[i].backOffEnabled {
                if let last = migrated[i].sets.last, !last.isBackOff, migrated[i].sets.count > 1 {
                    migrated[i].sets.removeLast()
                }
                migrated[i].backOffEnabled = false
            }
            exercises=migrated
            save()
            return
        }
    }

    private static func initialSchedule()->[Exercise] {
        func e(_ d:String,_ n:String,_ r:String,_ s:Int,_ g:String,_ f:String,_ t:MuscleTarget,_ rec:String)->Exercise { Exercise(day:d,name:n,group:g,focus:f,target:t,reps:r,numberOfSets:s,recovery:rec) }
        return [
            e("LUNEDÌ","Spinte manubri panca 32","7-9",3,"PETTO (ALTO)","Pettorali superiori e tricipiti",.chest,"2:00"), e("LUNEDÌ","Lat Pulldown","7-9",3,"DORSO","Gran dorsale e bicipiti",.back,"2:00"), e("LUNEDÌ","Chest Press","8-10",3,"PETTO","Pettorali e tricipiti",.chest,"2:00"), e("LUNEDÌ","T-Bar prona larga","8-10",3,"DORSO","Dorsali e parte alta della schiena",.back,"2:00"), e("LUNEDÌ","Alzate laterali","10-12",4,"SPALLE","Deltoide laterale",.shoulders,"1:30"), e("LUNEDÌ","Push Down asta curva","10 RM",4,"TRICIPITI","Tricipite",.triceps,"1:30"), e("LUNEDÌ","Curl cavo basso","10 RM",4,"BICIPITI","Bicipite",.biceps,"1:30"),
            e("MARTEDÌ","Leg Extension","12 RM",4,"QUADRICIPITI","Quadricipite",.quads,"1:30"), e("MARTEDÌ","Leg Press 45","7-9",3,"GAMBE","Quadricipiti e glutei",.quads,"2:00"), e("MARTEDÌ","Leg Curl sdraiato","10-12",2,"FEMORALI","Femorali",.hamstrings,"1:30"), e("MARTEDÌ","Adduttori","10-12",2,"ADDUTTORI","Adduttori",.quads,"1:30"), e("MARTEDÌ","Calf Machine","8-10",4,"POLPACCI","Polpacci",.hamstrings,"1:30"),
            e("MERCOLEDÌ","Panca piana bilanciere","7-9",4,"PETTO","Pettorali e tricipiti",.chest,"2:30"), e("MERCOLEDÌ","Rematore bilanciere","7-9",3,"DORSO","Dorsali e parte alta della schiena",.back,"2:00"), e("MERCOLEDÌ","Lento avanti manubri panca 71","8-10",3,"SPALLE","Deltoidi e tricipiti",.shoulders,"2:00"), e("MERCOLEDÌ","Rowing","8-10",3,"DORSO","Schiena",.back,"2:00"), e("MERCOLEDÌ","Stacchi rumeni manubri","7-9",3,"FEMORALI / GLUTEI","Catena posteriore",.hamstrings,"2:30"), e("MERCOLEDÌ","Leg Curl seduto","12 RM",2,"FEMORALI","Femorali",.hamstrings,"1:30"), e("MERCOLEDÌ","Arm Curl","10 RM",3,"BICIPITI","Bicipite",.biceps,"1:30"), e("MERCOLEDÌ","French Press manubri","10 RM",3,"TRICIPITI","Tricipite",.triceps,"1:30")
        ]
    }
}
