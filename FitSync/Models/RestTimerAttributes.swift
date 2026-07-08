import ActivityKit
import Foundation

struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startTime: Date
        var endTime: Date
    }

    var exerciseName: String
    var nextExerciseName: String?
    var mode: String // "setRest" or "transition"
    var totalSeconds: Int
}
