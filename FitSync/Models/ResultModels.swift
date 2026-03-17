import Foundation

struct ResultJSON: Codable {
    let schema: String
    let version: String
    let date: String
    let plan_ref: String?
    let start_time: String
    let end_time: String
    let duration_minutes: Int
    var exercises: [ResultExercise]
    var warmup_result: [ChecklistResult]?
    var cooldown_result: [ChecklistResult]?
    var overall_feeling: Int
    var journal: String
    var sleep_hours: Double
}

struct ResultExercise: Codable {
    let order: Int
    let name: String
    let type: String
    let planned: Bool
    var started_at: String?
    var sets: [StrengthSet]?
    var cardio_data: CardioData?
    var notes: String?
}

struct StrengthSet: Codable {
    var reps: Int
    var weight_kg: Double
    var rpe: Double?
    var completed_at: String?
}

struct CardioData: Codable {
    var incline_pct: Double?
    var speed_kmh: Double?
    var duration_minutes: Double
    var distance_km: Double?
}

struct ChecklistResult: Codable {
    let action: String
    var done: Bool
}
