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

// Storico di un peso utilizzato
struct WeightLog: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let weight: Double

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        weight: Double
    ) {
        self.id = id
        self.date = date
        self.weight = weight
    }
}

struct WorkoutSet: Codable, Equatable, Identifiable {
    let id: UUID
    var reps: String
    var weight: Double
    var completed: Bool

    // Storico dei pesi di questa specifica serie
    var history: [WeightLog]

    init(
        id: UUID = UUID(),
        reps: String,
        weight: Double = 20,
        completed: Bool = false,
        history: [WeightLog] = []
    ) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.completed = completed
        self.history = history
    }

    // Permette di leggere anche i vecchi dati salvati
    // che non avevano ancora "history".
    enum CodingKeys: String, CodingKey {
        case id
        case reps
        case weight
        case completed
        case history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        reps = try container.decode(String.self, forKey: .reps)
        weight = try container.decode(Double.self, forKey: .weight)
        completed = try container.decode(Bool.self, forKey: .completed)

        history = try container.decodeIfPresent(
            [WeightLog].self,
            forKey: .history
        ) ?? []
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

    init(
        id: UUID = UUID(),
        day: String,
        name: String,
        group: String,
        focus: String,
        target: MuscleTarget,
        reps: String,
        numberOfSets: Int,
        notes: String = "",
        recovery: String = ""
    ) {
        self.id = id
        self.day = day
        self.name = name
        self.group = group
        self.focus = focus
        self.target = target

        self.sets = (0..<numberOfSets).map { _ in
            WorkoutSet(reps: reps)
        }

        self.notes = notes
        self.recovery = recovery
    }
}
