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
    let sets: Int
    let target_reps: String
    let target_weight_kg: Double
    let rest_seconds: Int
    let transition_rest_seconds: Int?
    let notes: String?
    let coaching: ExerciseCoaching?

    var id: Int { order }
}

struct ExerciseCoaching: Codable {
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
