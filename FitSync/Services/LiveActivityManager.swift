import ActivityKit
import Foundation

final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<RestTimerAttributes>?
    private var currentStartTime: Date?

    func startTimer(exerciseName: String, nextExerciseName: String?, mode: String, endTime: Date, totalSeconds: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let currentActivity {
            let now = Date()
            let contentState = RestTimerAttributes.ContentState(startTime: now, endTime: now)
            Task {
                await currentActivity.end(.init(state: contentState, staleDate: nil), dismissalPolicy: .immediate)
            }
            self.currentActivity = nil
            currentStartTime = nil
        }
        
        let attributes = RestTimerAttributes(
            exerciseName: exerciseName,
            nextExerciseName: nextExerciseName,
            mode: mode,
            totalSeconds: totalSeconds
        )

        let startTime = endTime.addingTimeInterval(-TimeInterval(max(totalSeconds, 1)))
        currentStartTime = startTime
        let contentState = RestTimerAttributes.ContentState(startTime: startTime, endTime: endTime)
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil)
            )
        } catch {
            print("Error starting Live Activity: \(error.localizedDescription)")
        }
    }

    func updateTimer(endTime: Date, totalSeconds: Int? = nil) {
        guard let activity = currentActivity else { return }

        let startTime = timerStart(endTime: endTime, totalSeconds: totalSeconds ?? activity.attributes.totalSeconds)
        currentStartTime = startTime
        let contentState = RestTimerAttributes.ContentState(startTime: startTime, endTime: endTime)
        
        Task {
            await activity.update(.init(state: contentState, staleDate: nil))
        }
    }

    func stopTimer() {
        guard let activity = currentActivity else { return }

        let now = Date()
        let contentState = RestTimerAttributes.ContentState(
            startTime: now,
            endTime: now
        )
        currentActivity = nil
        currentStartTime = nil
        
        Task {
            await activity.end(.init(state: contentState, staleDate: nil), dismissalPolicy: .immediate)
        }
    }

    private func timerStart(endTime: Date, totalSeconds: Int) -> Date {
        if let currentStartTime {
            return currentStartTime
        }
        return endTime.addingTimeInterval(-TimeInterval(max(totalSeconds, 1)))
    }
}
