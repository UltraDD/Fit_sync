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

struct ResultExercise: Codable, Identifiable {
    var id: UUID

    let order: Int
    let name: String
    let type: String
    let planned: Bool
    var started_at: String?
    var sets: [StrengthSet]?
    var cardio_data: CardioData?
    var notes: String?

    init(order: Int, name: String, type: String, planned: Bool, started_at: String? = nil, sets: [StrengthSet]? = nil, cardio_data: CardioData? = nil, notes: String? = nil) {
        self.id = UUID()
        self.order = order
        self.name = name
        self.type = type
        self.planned = planned
        self.started_at = started_at
        self.sets = sets
        self.cardio_data = cardio_data
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case order, name, type, planned, started_at, sets, cardio_data, notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.order = try c.decode(Int.self, forKey: .order)
        self.name = try c.decode(String.self, forKey: .name)
        self.type = try c.decode(String.self, forKey: .type)
        self.planned = try c.decodeIfPresent(Bool.self, forKey: .planned) ?? true
        self.started_at = try c.decodeIfPresent(String.self, forKey: .started_at)
        self.sets = try c.decodeIfPresent([StrengthSet].self, forKey: .sets)
        self.cardio_data = try c.decodeIfPresent(CardioData.self, forKey: .cardio_data)
        self.notes = try c.decodeIfPresent(String.self, forKey: .notes)
    }
}

struct StrengthSet: Codable, Identifiable {
    let id: UUID
    var reps: Int?
    var weight_kg: Double?
    var duration_seconds: Int?
    var rpe: Double?
    var started_at: String?
    var completed_at: String?

    init(reps: Int? = nil, weight_kg: Double? = nil, duration_seconds: Int? = nil, rpe: Double? = nil, started_at: String? = nil, completed_at: String? = nil) {
        self.id = UUID()
        self.reps = reps
        self.weight_kg = weight_kg
        self.duration_seconds = duration_seconds
        self.rpe = rpe
        self.started_at = started_at
        self.completed_at = completed_at
    }

    private enum CodingKeys: String, CodingKey {
        case reps, weight_kg, duration_seconds, rpe, started_at, completed_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.reps = try c.decodeIfPresent(Int.self, forKey: .reps)
        self.weight_kg = try c.decodeIfPresent(Double.self, forKey: .weight_kg)
        self.duration_seconds = try c.decodeIfPresent(Int.self, forKey: .duration_seconds)
        self.rpe = try c.decodeIfPresent(Double.self, forKey: .rpe)
        self.started_at = try c.decodeIfPresent(String.self, forKey: .started_at)
        self.completed_at = try c.decodeIfPresent(String.self, forKey: .completed_at)
    }
}

struct CardioData: Codable {
    var incline_pct: Double?
    var speed_kmh: Double?
    var duration_minutes: Double
    var distance_km: Double?
}

struct ChecklistResult: Codable, Identifiable {
    let action: String
    var done: Bool

    var id: String { action }
}
