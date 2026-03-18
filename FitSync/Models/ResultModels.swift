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

    init(schema: String, version: String, date: String, plan_ref: String?,
         start_time: String, end_time: String, duration_minutes: Int,
         exercises: [ResultExercise], overall_feeling: Int,
         journal: String, sleep_hours: Double) {
        self.schema = schema; self.version = version; self.date = date
        self.plan_ref = plan_ref; self.start_time = start_time
        self.end_time = end_time; self.duration_minutes = duration_minutes
        self.exercises = exercises; self.overall_feeling = overall_feeling
        self.journal = journal; self.sleep_hours = sleep_hours
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decodeIfPresent(String.self, forKey: .schema) ?? "my_life.fitness.result"
        version = try c.decodeIfPresent(String.self, forKey: .version) ?? "1.2"
        date = try c.decode(String.self, forKey: .date)
        plan_ref = try c.decodeIfPresent(String.self, forKey: .plan_ref)
        start_time = try c.decodeIfPresent(String.self, forKey: .start_time) ?? ""
        end_time = try c.decodeIfPresent(String.self, forKey: .end_time) ?? ""
        duration_minutes = try c.decodeIfPresent(Int.self, forKey: .duration_minutes) ?? 0
        exercises = try c.decodeIfPresent([ResultExercise].self, forKey: .exercises) ?? []
        warmup_result = try c.decodeIfPresent([ChecklistResult].self, forKey: .warmup_result)
        cooldown_result = try c.decodeIfPresent([ChecklistResult].self, forKey: .cooldown_result)
        overall_feeling = try c.decodeIfPresent(Int.self, forKey: .overall_feeling) ?? 5
        journal = try c.decodeIfPresent(String.self, forKey: .journal) ?? ""
        sleep_hours = try c.decodeIfPresent(Double.self, forKey: .sleep_hours) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case schema, version, date, plan_ref, start_time, end_time
        case duration_minutes, exercises, warmup_result, cooldown_result
        case overall_feeling, journal, sleep_hours
    }
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
    var started_at: String?
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
