import Foundation

enum MuscleTarget: String, Codable, CaseIterable {
    case chest, back, shoulders, biceps, triceps, quads, hamstrings, fullBody
    var title: String {
        switch self { case .chest: return "PETTO"; case .back: return "DORSO"; case .shoulders: return "SPALLE"; case .biceps: return "BICIPITI"; case .triceps: return "TRICIPITI"; case .quads: return "QUADRICIPITI"; case .hamstrings: return "FEMORALI / GLUTEI"; case .fullBody: return "CORPO LIBERO / ALTRO" }
    }
}

struct WeightLog: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let weight: Double
    init(id: UUID = UUID(), date: Date = Date(), weight: Double) { self.id = id; self.date = date; self.weight = weight }
}

struct WorkoutSet: Codable, Equatable, Identifiable {
    let id: UUID
    var reps: String
    var weight: Double
    var completed: Bool
    var history: [WeightLog]
    init(id: UUID = UUID(), reps: String, weight: Double = 20, completed: Bool = false, history: [WeightLog] = []) { self.id=id; self.reps=reps; self.weight=weight; self.completed=completed; self.history=history }
    enum CodingKeys: String, CodingKey { case id, reps, weight, completed, history }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        reps = try c.decode(String.self, forKey: .reps)
        weight = try c.decodeIfPresent(Double.self, forKey: .weight) ?? 20
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        history = try c.decodeIfPresent([WeightLog].self, forKey: .history) ?? []
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
    init(id: UUID = UUID(), day: String, name: String, group: String, focus: String, target: MuscleTarget, reps: String, numberOfSets: Int, notes: String = "", recovery: String = "") {
        self.id=id; self.day=day; self.name=name; self.group=group; self.focus=focus; self.target=target
        self.sets = (0..<max(1, numberOfSets)).map { _ in WorkoutSet(reps: reps) }
        self.notes=notes; self.recovery=recovery
    }
}
