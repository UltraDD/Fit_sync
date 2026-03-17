import Foundation
import Observation

struct WorkoutDraft: Codable {
    let active: Bool
    let exercises: [LiveExercise]
    let startTime: String?
    let startTimestamp: Date?
    let warmupItems: [LiveChecklistItem]
    let cooldownItems: [LiveChecklistItem]
    let journalText: String
    let planDate: String?
}

struct LiveSet: Codable {
    var reps: Int
    var weight_kg: Double
    var rpe: Double?
    var completed: Bool
    var completed_at: String?
}

struct LiveChecklistItem: Codable, Identifiable {
    let action: String
    var detail: String?
    var done: Bool

    var id: String { action }
}

struct LiveExercise: Codable, Identifiable {
    let id: String
    var order: Int
    let name: String
    var type: String
    let planned: Bool
    var targetSets: Int
    var targetReps: String
    var targetWeight: Double
    var restSeconds: Int
    var transitionRestSeconds: Int
    var notes: String
    var coaching: ExerciseCoaching?
    var sets: [LiveSet]
    var cardioData: CardioData?
    var exerciseNotes: String
    var startedAt: String?

    var completedSets: Int { sets.filter(\.completed).count }
    var isComplete: Bool { type == "cardio" ? cardioData != nil : completedSets >= targetSets }
}

@Observable
final class WorkoutState {
    var active = false
    var plan: PlanJSON?
    var exercises: [LiveExercise] = []
    var startTime: String?
    var startTimestamp: Date?
    var elapsedSeconds: Int = 0
    var currentExerciseId: String?

    var warmupItems: [LiveChecklistItem] = []
    var cooldownItems: [LiveChecklistItem] = []
    var journalText: String = ""

    private var nextId = 1

    private func genId() -> String {
        let id = "ex-\(nextId)"
        nextId += 1
        return id
    }

    func startWorkout(plan: PlanJSON?) {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        startTime = formatter.string(from: now)
        startTimestamp = now
        elapsedSeconds = 0
        self.plan = plan
        currentExerciseId = nil
        journalText = ""

        if let plan {
            exercises = plan.exercises.map { pe in
                let sets = (0..<pe.sets).map { _ in
                    LiveSet(reps: 0, weight_kg: pe.target_weight_kg, completed: false)
                }
                return LiveExercise(
                    id: genId(),
                    order: pe.order,
                    name: pe.name,
                    type: "strength",
                    planned: true,
                    targetSets: pe.sets,
                    targetReps: pe.target_reps,
                    targetWeight: pe.target_weight_kg,
                    restSeconds: pe.rest_seconds,
                    transitionRestSeconds: pe.transition_rest_seconds ?? 90,
                    notes: pe.notes ?? "",
                    coaching: pe.coaching,
                    sets: sets,
                    exerciseNotes: ""
                )
            }
            warmupItems = (plan.warmup_items ?? []).map {
                LiveChecklistItem(action: $0.action, detail: $0.detail, done: false)
            }
            cooldownItems = (plan.cooldown_items ?? []).map {
                LiveChecklistItem(action: $0.action, detail: $0.detail, done: false)
            }
        } else {
            exercises = []
            warmupItems = []
            cooldownItems = []
        }

        active = true
        saveDraft()
    }

    func tick() {
        guard let start = startTimestamp else { return }
        elapsedSeconds = Int(Date().timeIntervalSince(start))
    }

    func startExercise(_ exerciseId: String) {
        currentExerciseId = exerciseId
        if let idx = exercises.firstIndex(where: { $0.id == exerciseId }),
           exercises[idx].startedAt == nil {
            exercises[idx].startedAt = ISO8601DateFormatter().string(from: Date())
        }
    }

    func completeSet(exerciseId: String, setIndex: Int, reps: Int, weight: Double, rpe: Double?) {
        guard let idx = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        guard setIndex < exercises[idx].sets.count else { return }
        exercises[idx].sets[setIndex].reps = reps
        exercises[idx].sets[setIndex].weight_kg = weight
        exercises[idx].sets[setIndex].rpe = rpe
        exercises[idx].sets[setIndex].completed = true
        exercises[idx].sets[setIndex].completed_at = ISO8601DateFormatter().string(from: Date())
        saveDraft()
    }

    func addSet(to exerciseId: String) {
        guard let idx = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        let weight = exercises[idx].targetWeight
        exercises[idx].sets.append(LiveSet(reps: 0, weight_kg: weight, completed: false))
    }

    func updateCardio(exerciseId: String, data: CardioData) {
        guard let idx = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        exercises[idx].cardioData = data
    }

    func updateExerciseNotes(exerciseId: String, notes: String) {
        guard let idx = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        exercises[idx].exerciseNotes = notes
    }

    func addExercise(name: String, type: String) {
        let isCardio = type == "cardio"
        let order = exercises.count + 1
        let sets: [LiveSet] = isCardio ? [] : (0..<3).map { _ in
            LiveSet(reps: 0, weight_kg: 0, completed: false)
        }
        exercises.append(LiveExercise(
            id: genId(),
            order: order,
            name: name,
            type: type,
            planned: false,
            targetSets: isCardio ? 1 : 3,
            targetReps: isCardio ? "" : "10-12",
            targetWeight: 0,
            restSeconds: 90,
            transitionRestSeconds: 90,
            notes: "",
            sets: sets,
            cardioData: isCardio ? CardioData(duration_minutes: 0) : nil,
            exerciseNotes: ""
        ))
    }

    func moveExercise(from: Int, to: Int) {
        guard from >= 0, from < exercises.count, to >= 0, to <= exercises.count else { return }
        let item = exercises.remove(at: from)
        exercises.insert(item, at: to > from ? to - 1 : to)
        for i in exercises.indices {
            exercises[i].order = i + 1
        }
    }

    func toggleWarmup(at index: Int) {
        guard index < warmupItems.count else { return }
        warmupItems[index].done.toggle()
    }

    func toggleCooldown(at index: Int) {
        guard index < cooldownItems.count else { return }
        cooldownItems[index].done.toggle()
    }

    func getNextExerciseId(after currentId: String) -> String? {
        guard let idx = exercises.firstIndex(where: { $0.id == currentId }),
              idx + 1 < exercises.count else { return nil }
        return exercises[idx + 1].id
    }

    func buildResult(feeling: Int, journal: String, sleepHours: Double) -> ResultJSON {
        let now = Date()
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let endTime = timeFmt.string(from: now)
        let today = DateUtils.dateOnly.string(from: now)

        let resultExercises: [ResultExercise] = exercises.map { ex in
            if ex.type == "strength" {
                let completedSets = ex.sets.filter(\.completed).map { s in
                    StrengthSet(
                        reps: s.reps,
                        weight_kg: s.weight_kg,
                        rpe: s.rpe,
                        completed_at: s.completed_at
                    )
                }
                return ResultExercise(
                    order: ex.order,
                    name: ex.name,
                    type: ex.type,
                    planned: ex.planned,
                    started_at: ex.startedAt,
                    sets: completedSets,
                    notes: ex.exerciseNotes.isEmpty ? nil : ex.exerciseNotes
                )
            } else {
                return ResultExercise(
                    order: ex.order,
                    name: ex.name,
                    type: ex.type,
                    planned: ex.planned,
                    started_at: ex.startedAt,
                    cardio_data: ex.cardioData,
                    notes: ex.exerciseNotes.isEmpty ? nil : ex.exerciseNotes
                )
            }
        }

        var result = ResultJSON(
            schema: "my_life.fitness.result",
            version: "1.2",
            date: today,
            plan_ref: plan?.date,
            start_time: startTime ?? "",
            end_time: endTime,
            duration_minutes: elapsedSeconds / 60,
            exercises: resultExercises,
            overall_feeling: feeling,
            journal: journal,
            sleep_hours: sleepHours
        )
        if !warmupItems.isEmpty {
            result.warmup_result = warmupItems.map { ChecklistResult(action: $0.action, done: $0.done) }
        }
        if !cooldownItems.isEmpty {
            result.cooldown_result = cooldownItems.map { ChecklistResult(action: $0.action, done: $0.done) }
        }
        return result
    }

    func reset() {
        active = false
        plan = nil
        exercises = []
        startTime = nil
        startTimestamp = nil
        elapsedSeconds = 0
        currentExerciseId = nil
        warmupItems = []
        cooldownItems = []
        journalText = ""
        clearDraft()
    }

    private static let draftKey = "workout_draft"

    func saveDraft() {
        let draft = WorkoutDraft(
            active: active,
            exercises: exercises,
            startTime: startTime,
            startTimestamp: startTimestamp,
            warmupItems: warmupItems,
            cooldownItems: cooldownItems,
            journalText: journalText,
            planDate: plan?.date
        )
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: Self.draftKey)
        }
    }

    func loadDraft() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.draftKey),
              let draft = try? JSONDecoder().decode(WorkoutDraft.self, from: data),
              draft.active else { return false }
        active = draft.active
        exercises = draft.exercises
        startTime = draft.startTime
        startTimestamp = draft.startTimestamp
        warmupItems = draft.warmupItems
        cooldownItems = draft.cooldownItems
        journalText = draft.journalText
        if let start = startTimestamp {
            elapsedSeconds = Int(Date().timeIntervalSince(start))
        }
        return true
    }

    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: Self.draftKey)
    }

    var elapsedFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var totalCompletedSets: Int {
        exercises.reduce(0) { $0 + $1.completedSets }
    }

    var maxWeight: (Double, String)? {
        var best: Double = 0
        var name = ""
        for ex in exercises {
            for s in ex.sets where s.completed && s.weight_kg > best {
                best = s.weight_kg
                name = ex.name
            }
        }
        return best > 0 ? (best, name) : nil
    }
}
