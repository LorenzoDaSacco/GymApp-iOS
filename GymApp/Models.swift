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

enum ScheduleMode: String, Codable, CaseIterable, Identifiable {
    case weekdays
    case trainingDays
    var id: String { rawValue }
    var title: String {
        switch self {
        case .weekdays: return "Giorni della settimana"
        case .trainingDays: return "Giorno 1, 2, 3…"
        }
    }
}

enum RepetitionMode: String, Codable, CaseIterable, Identifiable {
    case general
    case perSet
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "Ripetizioni generali"
        case .perSet: return "Ripetizioni per serie"
        }
    }
}

struct WeightLog: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let weight: Double
    init(id: UUID = UUID(), date: Date = Date(), weight: Double) {
        self.id = id; self.date = date; self.weight = weight
    }
}

struct WorkoutSet: Codable, Equatable, Identifiable {
    let id: UUID
    /// Ripetizioni effettivamente eseguite. La prescrizione è in prescribedReps.
    var reps: String
    var weight: Double
    var completed: Bool
    var completedAt: Date?
    var history: [WeightLog]
    var isBackOff: Bool
    /// Prescrizione della singola serie quando è attiva la modalità per-serie.
    var prescribedReps: String?

    init(id: UUID = UUID(), reps: String = "", weight: Double = 20, completed: Bool = false,
         completedAt: Date? = nil, history: [WeightLog] = [], isBackOff: Bool = false,
         prescribedReps: String? = nil) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.completed = completed
        self.completedAt = completedAt
        self.history = history
        self.isBackOff = isBackOff
        self.prescribedReps = prescribedReps
    }

    enum CodingKeys: String, CodingKey {
        case id, reps, weight, completed, completedAt, history, isBackOff, prescribedReps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        let rawReps = try c.decodeIfPresent(String.self, forKey: .reps) ?? ""
        weight = try c.decodeIfPresent(Double.self, forKey: .weight) ?? 20
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        history = try c.decodeIfPresent([WeightLog].self, forKey: .history) ?? []
        isBackOff = try c.decodeIfPresent(Bool.self, forKey: .isBackOff) ?? false
        prescribedReps = try c.decodeIfPresent(String.self, forKey: .prescribedReps)

        // Migrazione dai dati precedenti: il vecchio campo reps conteneva anche
        // la prescrizione (es. 8-10 / 10 RM). Se non è numerico la conserviamo
        // come prescrizione e lasciamo vuote le ripetizioni effettive.
        if prescribedReps == nil, WorkoutSet.looksLikePrescription(rawReps) {
            reps = ""
            prescribedReps = rawReps
        } else {
            reps = rawReps == "0" ? "" : rawReps
        }
    }

    private static func looksLikePrescription(_ value: String) -> Bool {
        let s = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.contains("RM") || s.contains("-") || s.contains("×") || s.contains("X") { return true }
        return s.isEmpty == false && Int(s) == nil
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
    var targetReps: String
    var notes: String
    var recovery: String
    var backOffEnabled: Bool

    init(id: UUID = UUID(), day: String, name: String, group: String, focus: String,
         target: MuscleTarget, reps: String, numberOfSets: Int, notes: String = "",
         recovery: String = "", backOffEnabled: Bool = false, perSetReps: [String]? = nil) {
        self.id = id; self.day = day; self.name = name; self.group = group
        self.focus = focus; self.target = target
        self.targetReps = reps
        self.sets = (0..<max(1, numberOfSets)).map { index in
            WorkoutSet(reps: "", prescribedReps: perSetReps?[safe: index] ?? nil)
        }
        self.notes = notes; self.recovery = recovery; self.backOffEnabled = backOffEnabled
    }

    enum CodingKeys: String, CodingKey {
        case id, day, name, group, focus, target, sets, targetReps, notes, recovery, backOffEnabled
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
        let decodedTarget = try c.decodeIfPresent(String.self, forKey: .targetReps)
        let fallback = sets.compactMap { $0.prescribedReps }.first ?? "8-10"
        targetReps = decodedTarget ?? fallback
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        recovery = try c.decodeIfPresent(String.self, forKey: .recovery) ?? ""
        backOffEnabled = try c.decodeIfPresent(Bool.self, forKey: .backOffEnabled) ?? false
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
