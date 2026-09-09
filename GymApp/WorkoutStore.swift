
import Foundation
import Combine

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var selectedDay = "UPPER" { didSet { save() } }
    @Published var exercises: [Exercise] = [] { didSet { save() } }

    let days = ["UPPER", "LOWER", "FULLBODY"]
    private let key = "gymapp.native.v3"

    init() {
        load()
        if exercises.isEmpty { exercises = Self.initialSchedule() }
    }

    var dayExercises: [Exercise] { exercises.filter { $0.day == selectedDay } }

    var totalSets: Int { dayExercises.reduce(0) { $0 + $1.sets.count } }
    var completedSets: Int { dayExercises.reduce(0) { $0 + $1.sets.filter(\.completed).count } }
    var volume: Double { dayExercises.reduce(0) { $0 + $1.sets.filter(\.completed).reduce(0) { $0 + $1.weight } } }

    func updateWeight(_ weight: Double, exerciseID: UUID, setID: UUID) {
        guard let ei = exercises.firstIndex(where: {$0.id == exerciseID}),
              let si = exercises[ei].sets.firstIndex(where: {$0.id == setID}) else { return }
        exercises[ei].sets[si].weight = weight
    }

    func toggle(_ exerciseID: UUID, setID: UUID) {
        guard let ei = exercises.firstIndex(where: {$0.id == exerciseID}),
              let si = exercises[ei].sets.firstIndex(where: {$0.id == setID}) else { return }
        exercises[ei].sets[si].completed.toggle()
    }

    func addExercise(day: String, name: String, reps: String, numberOfSets: Int, weight: Double) {
        let r = ExerciseRecognizer.recognize(name)
        var e = Exercise(day: day, name: name, group: r.group, focus: r.focus, target: r.target,
                         reps: reps, numberOfSets: numberOfSets)
        e.sets = e.sets.map { _ in WorkoutSet(reps: reps, weight: weight) }
        exercises.append(e)
        selectedDay = day
    }

    func remove(_ exercise: Exercise) { exercises.removeAll { $0.id == exercise.id } }

    func resetDay() {
        for i in exercises.indices where exercises[i].day == selectedDay {
            for j in exercises[i].sets.indices { exercises[i].sets[j].completed = false }
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(exercises) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Exercise].self, from: data) else { return }
        exercises = decoded
    }

    private static func initialSchedule() -> [Exercise] {
        func e(_ d:String,_ n:String,_ r:String,_ s:Int,_ g:String,_ f:String,_ t:MuscleTarget,_ rec:String) -> Exercise {
            Exercise(day:d,name:n,group:g,focus:f,target:t,reps:r,numberOfSets:s,recovery:rec)
        }
        return [
            e("UPPER","Spinte manubri panca 32","7-9",3,"PETTO (ALTO)","Pettorali superiori e tricipiti",.chest,"2:00"),
            e("UPPER","Lat Pulldown","7-9",3,"DORSO","Gran dorsale e bicipiti",.back,"2:00"),
            e("UPPER","Chest Press","8-10",3,"PETTO","Pettorali e tricipiti",.chest,"2:00"),
            e("UPPER","T-Bar prona larga","8-10",3,"DORSO","Dorsali, romboidi e trapezio",.back,"1:30"),
            e("UPPER","Alzate laterali","10-12",3,"SPALLE","Deltoide laterale",.shoulders,"1:30"),
            e("UPPER","Push Down asta curva","10 RM",3,"TRICIPITI","Tricipiti",.triceps,"1:30"),
            e("UPPER","Curl cavo basso","10 RM",3,"BICIPITI","Bicipiti",.biceps,"1:30"),
            e("LOWER","Leg Extension","12 RM",3,"QUADRICIPITI","Quadricipiti",.quads,"1:30"),
            e("LOWER","Leg Press 45","7-9",3,"GAMBE (QUADRICIPITI)","Quadricipiti e glutei",.quads,"2:00"),
            e("LOWER","Leg Curl sdraiato","10-12",2,"FEMORALI","Femorali",.hamstrings,"1:30"),
            e("LOWER","Adduttori","10-12",2,"ADDUTTORI","Adduttori",.hamstrings,"1:30"),
            e("LOWER","Calf Machine","8-10",3,"POLPACCI","Polpacci",.quads,"1:30"),
            e("FULLBODY","Panca piana bilanciere","7-9",3,"PETTO","Pettorali e tricipiti",.chest,"2:30"),
            e("FULLBODY","Rematore bilanciere","7-9",3,"DORSO","Dorsali, romboidi e bicipiti",.back,"2:30"),
            e("FULLBODY","Lento avanti manubri panca 71","8-10",3,"SPALLE","Deltoidi e tricipiti",.shoulders,"2:00"),
            e("FULLBODY","Rowing","8-10",3,"DORSO","Dorsali e romboidi",.back,"1:30"),
            e("FULLBODY","Stacchi rumeni manubri","7-9",3,"FEMORALI / GLUTEI","Catena posteriore e glutei",.hamstrings,"2:00"),
            e("FULLBODY","Leg Curl seduto","12 RM",2,"FEMORALI","Femorali",.hamstrings,"1:30"),
            e("FULLBODY","Arm Curl","10 RM",3,"BICIPITI","Bicipiti",.biceps,"1:30"),
            e("FULLBODY","French Press manubri","10 RM",3,"TRICIPITI","Tricipiti",.triceps,"1:30")
        ]
    }
}
