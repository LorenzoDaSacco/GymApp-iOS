import Foundation
import Combine

@MainActor
final class WorkoutStore: ObservableObject {

    @Published var selectedDay = "LUNEDÌ" { didSet { save() } }
    @Published var exercises: [Exercise] = [] { didSet { save() } }

    let days = ["LUNEDÌ", "MARTEDÌ", "MERCOLEDÌ", "GIOVEDÌ", "VENERDÌ"]

    private let key = "gymapp.native.v4"

    init() {
        load()

        if exercises.isEmpty {
            exercises = Self.initialSchedule()
        }
    }

    var dayExercises: [Exercise] {
        exercises.filter { $0.day == selectedDay }
    }

    var totalSets: Int {
        dayExercises.reduce(0) { $0 + $1.sets.count }
    }

    var completedSets: Int {
        dayExercises.reduce(0) {
            $0 + $1.sets.filter(\.completed).count
        }
    }

    func updateWeight(_ weight: Double, exerciseID: UUID, setID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }),
              let si = exercises[ei].sets.firstIndex(where: { $0.id == setID })
        else { return }

        exercises[ei].sets[si].weight = weight
    }

    func toggle(_ exerciseID: UUID, setID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exerciseID }),
              let si = exercises[ei].sets.firstIndex(where: { $0.id == setID })
        else { return }

        exercises[ei].sets[si].completed.toggle()
    }

    func addSet(to exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else {
            return
        }

        let last = exercises[index].sets.last

        exercises[index].sets.append(
            WorkoutSet(
                reps: last?.reps ?? "8-10",
                weight: last?.weight ?? 20
            )
        )
    }

    func removeSet(from exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }),
              exercises[index].sets.count > 1
        else {
            return
        }

        exercises[index].sets.removeLast()
    }

    func addExercise(
        day: String,
        name: String,
        reps: String,
        weights: [Double]
    ) {
        let r = ExerciseRecognizer.recognize(name)

        var exercise = Exercise(
            day: day,
            name: name,
            group: r.group,
            focus: r.focus,
            target: r.target,
            reps: reps,
            numberOfSets: weights.count
        )

        exercise.sets = weights.map {
            WorkoutSet(reps: reps, weight: $0)
        }

        exercises.append(exercise)
        selectedDay = day
    }

    func remove(_ exercise: Exercise) {
        exercises.removeAll { $0.id == exercise.id }
    }

    func resetDay() {
        for i in exercises.indices where exercises[i].day == selectedDay {
            for j in exercises[i].sets.indices {
                exercises[i].sets[j].completed = false
            }
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(exercises) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Exercise].self, from: data)
        else {
            return
        }

        exercises = decoded
    }

    private static func initialSchedule() -> [Exercise] {

        func e(
            _ day: String,
            _ name: String,
            _ reps: String,
            _ sets: Int,
            _ group: String,
            _ focus: String,
            _ target: MuscleTarget,
            _ recovery: String
        ) -> Exercise {

            Exercise(
                day: day,
                name: name,
                group: group,
                focus: focus,
                target: target,
                reps: reps,
                numberOfSets: sets,
                recovery: recovery
            )
        }

        return [

            // LUNEDÌ
            e("LUNEDÌ", "Spinte manubri panca 32", "7-9", 3,
              "PETTO (ALTO)", "Pettorali superiori e tricipiti", .chest, "2:00"),

            e("LUNEDÌ", "Lat Pulldown", "7-9", 3,
              "DORSO", "Gran dorsale e bicipiti", .back, "2:00"),

            e("LUNEDÌ", "Chest Press", "8-10", 3,
              "PETTO", "Pettorali e tricipiti", .chest, "2:00"),

            e("LUNEDÌ", "T-Bar prona larga", "8-10", 3,
              "DORSO", "Dorsali, romboidi e trapezio", .back, "1:30"),

            e("LUNEDÌ", "Alzate laterali", "10-12", 3,
              "SPALLE", "Deltoide laterale", .shoulders, "1:30"),

            e("LUNEDÌ", "Push Down asta curva", "10 RM", 3,
              "TRICIPITI", "Tricipiti", .triceps, "1:30"),

            e("LUNEDÌ", "Curl cavo basso", "10 RM", 3,
              "BICIPITI", "Bicipiti", .biceps, "1:30"),

            // MARTEDÌ
            e("MARTEDÌ", "Leg Extension", "12 RM", 3,
              "QUADRICIPITI", "Quadricipiti", .quads, "1:30"),

            e("MARTEDÌ", "Leg Press 45", "7-9", 3,
              "GAMBE", "Quadricipiti e glutei", .quads, "2:00"),

            e("MARTEDÌ", "Leg Curl sdraiato", "10-12", 2,
              "FEMORALI", "Femorali", .hamstrings, "1:30"),

            e("MARTEDÌ", "Adduttori", "10-12", 2,
              "ADDUTTORI", "Adduttori", .hamstrings, "1:30"),

            e("MARTEDÌ", "Calf Machine", "8-10", 3,
              "POLPACCI", "Polpacci", .quads, "1:30"),

            // MERCOLEDÌ
            e("MERCOLEDÌ", "Panca piana bilanciere", "7-8", 4,
              "PETTO", "Pettorali e tricipiti", .chest, "2:30"),

            e("MERCOLEDÌ", "Rematore bilanciere", "7-9", 3,
              "DORSO", "Dorsali, romboidi e bicipiti", .back, "2:30"),

            e("MERCOLEDÌ", "Lento avanti manubri panca 71", "8-10", 3,
              "SPALLE", "Deltoidi e tricipiti", .shoulders, "2:00"),

            e("MERCOLEDÌ", "Rowing", "8-10", 3,
              "DORSO", "Dorsali e romboidi", .back, "1:30"),

            e("MERCOLEDÌ", "Stacchi rumeni manubri", "7-9", 3,
              "FEMORALI / GLUTEI", "Catena posteriore e glutei", .hamstrings, "2:00"),

            e("MERCOLEDÌ", "Leg Curl seduto", "12 RM", 2,
              "FEMORALI", "Femorali", .hamstrings, "1:30"),

            e("MERCOLEDÌ", "Arm Curl", "10 RM", 3,
              "BICIPITI", "Bicipiti", .biceps, "1:30"),

            e("MERCOLEDÌ", "French Press manubri", "10 RM", 3,
              "TRICIPITI", "Tricipiti", .triceps, "1:30")
        ]
    }
}
