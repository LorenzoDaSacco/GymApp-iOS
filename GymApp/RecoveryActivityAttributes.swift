import ActivityKit

struct RecoveryActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
    }

    var setID: UUID
    var exerciseName: String
    var duration: TimeInterval
}
