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

enum RepScheme: String, Codable, CaseIterable {
    case general
    case specific

    var title: String {
        switch self {
        case .general: return "Ripetizioni generali"
        case .specific: return "Ripetizioni per serie"
        }
    }
}

enum ScheduleMode: String, Codable, CaseIterable {
    case weekdays
    case numbered

    var title: String {
        switch self {
        case .weekdays: return "Giorni della settimana"
        case .numbered: return "Giorno 1, 2, 3…"
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
    var completedAt: Date?
    var history: [WeightLog]
    var isBackOff: Bool

    init(
        id: UUID = UUID(),
        reps: String,
        weight: Double = 20,
        completed: Bool = false,
        completedAt: Date? = nil,
        history: [WeightLog] = [],
        isBackOff: Bool = false
    ) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.completed = completed
        self.completedAt = completedAt
        self.history = history
        self.isBackOff = isBackOff
    }

    enum CodingKeys: String, CodingKey {
        case id, reps, weight, completed, completedAt, history, isBackOff
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        reps = try c.decode(String.self, forKey: .reps)
        weight = try c.decodeIfPresent(Double.self, forKey: .weight) ?? 20
        completed = try c.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        history = try c.decodeIfPresent([WeightLog].self, forKey: .history) ?? []
        isBackOff = try c.decodeIfPresent(Bool.self, forKey: .isBackOff) ?? false
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
    var backOffEnabled: Bool
    var repScheme: RepScheme
    var targetRepsBySet: [String]

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
        backOffEnabled: Bool = false,
        repScheme: RepScheme = .general,
        targetRepsBySet: [String]? = nil
    ) {
        self.id = id
        self.day = day
        self.name = name
        self.group = group
        self.focus = focus
        self.target = target
        self.sets = (0..<max(1, numberOfSets)).map { _ in WorkoutSet(reps: "", weight: 20) }
        self.notes = notes
        self.recovery = recovery
        self.backOffEnabled = backOffEnabled
        self.repScheme = repScheme
        self.targetRepsBySet = targetRepsBySet ?? Array(repeating: reps, count: max(1, numberOfSets))
    }

    var generalTargetReps: String {
        targetRepsBySet.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? "8-10"
    }

    func targetReps(for index: Int) -> String {
        guard repScheme == .specific, targetRepsBySet.indices.contains(index) else { return generalTargetReps }
        return targetRepsBySet[index].isEmpty ? generalTargetReps : targetRepsBySet[index]
    }

    enum CodingKeys: String, CodingKey {
        case id, day, name, group, focus, target, sets, notes, recovery, backOffEnabled, repScheme, targetRepsBySet
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

        let oldGeneral = sets.first?.reps.isEmpty == false ? sets.first!.reps : "8-10"
        repScheme = try c.decodeIfPresent(RepScheme.self, forKey: .repScheme) ?? .general
        targetRepsBySet = try c.decodeIfPresent([String].self, forKey: .targetRepsBySet) ?? Array(repeating: oldGeneral, count: max(1, sets.count))
        if targetRepsBySet.count < sets.count {
            targetRepsBySet += Array(repeating: oldGeneral, count: sets.count - targetRepsBySet.count)
        } else if targetRepsBySet.count > sets.count {
            targetRepsBySet = Array(targetRepsBySet.prefix(sets.count))
        }

        // Legacy data stored the prescription inside WorkoutSet.reps.
        // Convert obvious prescription strings to empty actual-reps fields while preserving numeric actual reps.
        let looksLikePrescription: (String) -> Bool = { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return trimmed.contains("RM") || trimmed.contains("-") || trimmed.contains("×") || trimmed.contains("X")
        }
        if c.contains(.repScheme) == false {
            let legacyTarget = sets.first?.reps.trimmingCharacters(in: .whitespacesAndNewlines)
            if let legacyTarget, !legacyTarget.isEmpty, looksLikePrescription(legacyTarget) {
                targetRepsBySet = Array(repeating: legacyTarget, count: max(1, sets.count))
                repScheme = .general
                sets = sets.map { old in
                    var value = old
                    if looksLikePrescription(old.reps) { value.reps = "" }
                    return value
                }
            }
        }
    }
}
