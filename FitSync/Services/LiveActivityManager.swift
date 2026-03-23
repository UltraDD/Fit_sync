import ActivityKit
import Foundation

class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<RestTimerAttributes>?

    func startTimer(exerciseName: String, nextExerciseName: String?, mode: String, seconds: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = RestTimerAttributes(
            exerciseName: exerciseName,
            nextExerciseName: nextExerciseName,
            mode: mode
        )
        
        let contentState = RestTimerAttributes.ContentState(
            endTime: Date().addingTimeInterval(TimeInterval(seconds)),
            remainingSeconds: seconds
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

    func updateTimer(seconds: Int) {
        guard let activity = currentActivity else { return }
        
        let contentState = RestTimerAttributes.ContentState(
            endTime: Date().addingTimeInterval(TimeInterval(seconds)),
            remainingSeconds: seconds
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
