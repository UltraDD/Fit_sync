import ActivityKit
import Foundation

class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<RestTimerAttributes>?

    func startTimer(exerciseName: String, nextExerciseName: String?, mode: String, endTime: Date, totalSeconds: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = RestTimerAttributes(
            exerciseName: exerciseName,
            nextExerciseName: nextExerciseName,
            mode: mode,
            totalSeconds: totalSeconds
        )
        
        let remaining = max(0, Int(ceil(endTime.timeIntervalSinceNow)))
        let contentState = RestTimerAttributes.ContentState(
            endTime: endTime,
            remainingSeconds: remaining
        )
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil)
            )
        } catch {
            print("Error starting Live Activity: \(error.localizedDescription)")
        }
    }

    func updateTimer(endTime: Date) {
        guard let activity = currentActivity else { return }
        
        let remaining = max(0, Int(ceil(endTime.timeIntervalSinceNow)))
        let contentState = RestTimerAttributes.ContentState(
            endTime: endTime,
            remainingSeconds: remaining
        )
        
        Task {
            await activity.update(.init(state: contentState, staleDate: nil))
        }
    }

    func stopTimer() {
        guard let activity = currentActivity else { return }
        
        let contentState = RestTimerAttributes.ContentState(
            endTime: Date(),
            remainingSeconds: 0
        )
        
        Task {
            await activity.end(.init(state: contentState, staleDate: nil), dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }
}
