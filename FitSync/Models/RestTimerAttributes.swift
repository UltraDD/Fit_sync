import ActivityKit
import Foundation

struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endTime: Date
        var remainingSeconds: Int
    }

    var exerciseName: String
    var nextExerciseName: String?
    var mode: String // "setRest" or "transition"
}
