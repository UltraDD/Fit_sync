import Foundation

struct PlanJSON: Codable {
    let schema: String
    let version: String
    let date: String
    let type: String
    let target_muscles: [String]
    let estimated_minutes: Int
    let warmup_items: [ChecklistItem]?
    let exercises: [PlanExercise]
    let cooldown_items: [ChecklistItem]?
    let coach_greeting: String?
    let coach_notes: String?
}

struct PlanExercise: Codable, Identifiable {
    let order: Int
    let name: String
    let type: String? // "strength", "duration", "core", "cardio"
    let sets: Int
    let target_reps: String?
    let target_weight_kg: Double?
    let target_duration_seconds: Int?
    let target_cardio: TargetCardio?
    let rest_seconds: Int
    let transition_rest_seconds: Int?
    let notes: String?
    let coaching: ExerciseCoaching?

    var id: Int { order }
}

struct TargetCardio: Codable {
    let duration_minutes: Int
    let incline_pct: Double?
    let speed_kmh: Double?
    let target_hr_range: [Int]?
}

struct ExerciseCoaching: Codable {
    let key_cues: [String]?
    let setup: String?
    let execution: String?
    let breathing: String?
    let tips: [String]?
    let mistakes: [String]?
}

struct ChecklistItem: Codable, Identifiable {
    let action: String
    let detail: String?

    var id: String { action }
}
