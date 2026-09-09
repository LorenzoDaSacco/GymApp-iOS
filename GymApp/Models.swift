
import Foundation

enum MuscleTarget: String, Codable, CaseIterable {
    case chest, back, shoulders, biceps, triceps, quads, hamstrings, fullBody

    var title: String {
        switch self {
        case .chest: return "PETTO"
        case .back: return "DORSO"
        case .shoulders: return "SPALLE"
        case .biceps: return "BICIPITI"
        case .triceps: return "TRICIPITI"
        case .quads: return "QUADRICIPITI"
        case .hamstrings: return "FEMORALI / GLUTEI"
        case .fullBody: return "CORPO LIBERO / ALTRO"
        }
    }
}

struct WorkoutSet: Codable, Equatable, Identifiable {
    let id: UUID
    var reps: String
    var weight: Double
    var completed: Bool

    init(id: UUID = UUID(), reps: String, weight: Double = 20, completed: Bool = false) {
        self.id = id; self.reps = reps; self.weight = weight; self.completed = completed
    }
}

struct Exercise: Identifiable, Codable, Equatable {
    let id: UUID
    var day: String
    var name: String
    var group: String
    var focus: String
    var target: MuscleTarget
    var sets: [WorkoutSet]
    var notes: String
    var recovery: String

    init(id: UUID = UUID(), day: String, name: String, group: String, focus: String,
         target: MuscleTarget, reps: String, numberOfSets: Int, notes: String = "", recovery: String = "") {
        self.id = id; self.day = day; self.name = name; self.group = group
        self.focus = focus; self.target = target
        self.sets = (0..<numberOfSets).map { _ in WorkoutSet(reps: reps) }
        self.notes = notes; self.recovery = recovery
    }
}
