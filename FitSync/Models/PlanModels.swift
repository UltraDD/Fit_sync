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

    private enum CodingKeys: String, CodingKey {
        case order, name, type, sets, target_reps, target_weight_kg, target_duration_seconds
        case target_cardio, rest_seconds, transition_rest_seconds, notes, coaching
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        order = try container.decode(Int.self, forKey: .order)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        sets = try container.decode(Int.self, forKey: .sets)
        target_reps = Self.normalizedTargetReps(
            try container.decodeIfPresent(String.self, forKey: .target_reps)
        )
        target_weight_kg = try container.decodeIfPresent(Double.self, forKey: .target_weight_kg)
        target_duration_seconds = try container.decodeIfPresent(Int.self, forKey: .target_duration_seconds)
        target_cardio = try container.decodeIfPresent(TargetCardio.self, forKey: .target_cardio)
        rest_seconds = try container.decode(Int.self, forKey: .rest_seconds)
        transition_rest_seconds = try container.decodeIfPresent(Int.self, forKey: .transition_rest_seconds)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        coaching = try container.decodeIfPresent(ExerciseCoaching.self, forKey: .coaching)
    }

    static func normalizedTargetReps(_ value: String?) -> String? {
        guard var value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        let unitSuffixes = ["次", "下", "repetitions", "repetition", "reps", "rep"]
        var removedSuffix = true
        while removedSuffix {
            removedSuffix = false
            for suffix in unitSuffixes where value.lowercased().hasSuffix(suffix) {
                value = String(value.dropLast(suffix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                removedSuffix = true
            }
        }

        return value.isEmpty ? nil : value
    }
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
