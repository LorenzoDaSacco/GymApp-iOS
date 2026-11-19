import Foundation
import ActivityKit

struct RecoveryActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endDate: Date
        var exerciseName: String
        var recoveryText: String
    }

    var setID: String
}
