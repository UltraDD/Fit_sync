import Foundation

struct SyncPayload: Codable {
    let sync_time: String
    let period: SyncPeriod
    let heartrate_detail: [HeartRateDetailRecord]
    let resting_hr: [RestingHRRecord]
    let hrv: [HRVRecord]
    let steps_daily: [StepsDailyRecord]
    let active_calories: [CaloriesRecord]
    let basal_energy: [CaloriesRecord]
    let distance_daily: [DistanceRecord]
    let stand_hours: [StandHoursRecord]
    let exercise_minutes: [ExerciseMinutesRecord]
    let sleep: [SleepNightlyRecord]
    let workouts: [HealthWorkoutRecord]
    let vo2max: [VO2MaxRecord]
    let body_mass: [BodyMassRecord]
    let body_fat: [BodyFatRecord]
    let walking_hr: [WalkingHRRecord]
}

struct SyncPeriod: Codable {
    let from: String
    let to: String
}

struct HeartRateDetailRecord: Codable {
    let timestamp: String
    let bpm: Double
}

struct RestingHRRecord: Codable {
    let date: String
    let bpm: Double
}

struct HRVRecord: Codable {
    let date: String
    let sdnn_ms: Double
}

struct StepsDailyRecord: Codable {
    let date: String
    let steps: Int
}

struct CaloriesRecord: Codable {
    let date: String
    let kcal: Double
}

struct DistanceRecord: Codable {
    let date: String
    let km: Double
}

struct StandHoursRecord: Codable {
    let date: String
    let hours: Double
}

struct ExerciseMinutesRecord: Codable {
    let date: String
    let minutes: Double
}

struct SleepNightlyRecord: Codable {
    let date: String
    let inbed_hrs: Double
    let asleep_hrs: Double
    let deep_hrs: Double
    let rem_hrs: Double
    let core_hrs: Double
    let awake_hrs: Double
}

struct HealthWorkoutRecord: Codable {
    let date: String
    let type: String
    let duration_min: Double
    let calories: Double
    let avg_hr: Double
    let max_hr: Double
    let distance_km: Double
}

struct VO2MaxRecord: Codable {
    let date: String
    let ml_kg_min: Double
}

struct BodyMassRecord: Codable {
    let date: String
    let kg: Double
}

struct BodyFatRecord: Codable {
    let date: String
    let pct: Double
}

struct WalkingHRRecord: Codable {
    let date: String
    let bpm: Double
}

struct SyncHistoryEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let success: Bool
    let recordCount: Int
    let fileSize: Int
    let filePath: String
    let errorMessage: String?

    init(date: Date = .now, success: Bool, recordCount: Int = 0, fileSize: Int = 0, filePath: String = "", errorMessage: String? = nil) {
        self.id = UUID()
        self.date = date
        self.success = success
        self.recordCount = recordCount
        self.fileSize = fileSize
        self.filePath = filePath
        self.errorMessage = errorMessage
    }
}
