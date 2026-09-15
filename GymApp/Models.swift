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

struct WeightLog: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let weight: Double

    init(id: UUID = UUID(), date: Date = Date(), weight: Double) {
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
    var history: [WeightLog]
    var isBackOff: Bool

    init(
        id: UUID = UUID(),
        reps: String = "",
        weight: Double = 20,
        completed: Bool = false,
        history: [WeightLog] = [],
        isBackOff: Bool = false
    ) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.completed = completed
        self.history = history
        self.isBackOff = isBackOff
    }

    enum CodingKeys: String, CodingKey {
        case id, reps, weight, completed, history, isBackOff
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        reps = try c.decodeIfPresent(String.self, forKey: .reps) ?? ""
        weight = try c.decodeIfPresent(Double.self, forKey: .weight) ?? 20
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        history = try c.decodeIfPresent([WeightLog].self, forKey: .history) ?? []
        isBackOff = try c.decodeIfPresent(Bool.self, forKey: .isBackOff) ?? false
    }
}

/// Snapshot di una singola serie in una sessione completata.
struct SessionSetRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let setIndex: Int
    let weight: Double
    let reps: Int
    let isBackOff: Bool

    init(id: UUID = UUID(), setIndex: Int, weight: Double, reps: Int, isBackOff: Bool = false) {
        self.id = id
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.isBackOff = isBackOff
    }

    var volume: Double { weight * Double(reps) }
}

/// Snapshot dell'esercizio in una giornata di allenamento.
struct ExerciseSession: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    var sets: [SessionSetRecord]

    init(id: UUID = UUID(), date: Date = Date(), sets: [SessionSetRecord]) {
        self.id = id
        self.date = date
        self.sets = sets
    }

    var volume: Double { sets.reduce(0) { $0 + $1.volume } }
}

struct Exercise: Identifiable, Codable, Equatable {
    let id: UUID
    var day: String
    var name: String
    var group: String
    var focus: String
    var target: MuscleTarget
    /// Range di ripetizioni deciso dalla scheda della palestra, non dalle performance dell'utente.
    var targetReps: String
    var sets: [WorkoutSet]
    var notes: String
    var recovery: String
    var backOffEnabled: Bool
    /// Storico delle sessioni complete dell'esercizio.
    var sessions: [ExerciseSession]

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
        recovery: String = "",
        backOffEnabled: Bool = false
    ) {
        self.id = id
        self.day = day
        self.name = name
        self.group = group
        self.focus = focus
        self.target = target
        self.targetReps = reps
        self.sets = (0..<max(1, numberOfSets)).map { _ in WorkoutSet(reps: "") }
        self.notes = notes
        self.recovery = recovery
        self.backOffEnabled = backOffEnabled
        self.sessions = []
    }

    enum CodingKeys: String, CodingKey {
        case id, day, name, group, focus, target, targetReps, sets, notes, recovery, backOffEnabled, sessions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        day = try c.decode(String.self, forKey: .day)
        name = try c.decode(String.self, forKey: .name)
        group = try c.decode(String.self, forKey: .group)
        focus = try c.decode(String.self, forKey: .focus)
        target = try c.decode(MuscleTarget.self, forKey: .target)
        sets = try c.decode([WorkoutSet].self, forKey: .sets)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        recovery = try c.decodeIfPresent(String.self, forKey: .recovery) ?? ""
        backOffEnabled = try c.decodeIfPresent(Bool.self, forKey: .backOffEnabled) ?? false
        sessions = try c.decodeIfPresent([ExerciseSession].self, forKey: .sessions) ?? []

        // Compatibilità con i dati precedenti: prima il range della scheda veniva
        // memorizzato dentro WorkoutSet.reps. Lo recuperiamo come targetReps.
        if let savedTarget = try c.decodeIfPresent(String.self, forKey: .targetReps), !savedTarget.isEmpty {
            targetReps = savedTarget
        } else {
            let legacy = sets.first?.reps.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            targetReps = Self.looksLikePrescription(legacy) ? legacy : "8-10"
        }
    }

    private static func looksLikePrescription(_ value: String) -> Bool {
        let normalized = value.uppercased().replacingOccurrences(of: " ", with: "")
        if normalized.contains("RM") || normalized.contains("-") || normalized.contains("×") || normalized.contains("X") {
            return true
        }
        return false
    }
}
