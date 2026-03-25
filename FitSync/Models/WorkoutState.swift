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
    let planMuscles: String?
    let exerciseTimes: [String: Int]
    let elapsedSeconds: Int
    let currentExerciseId: String?
}

struct LiveSet: Codable, Equatable, Identifiable {
    let id: UUID
    var reps: Int
    var weight_kg: Double
    var duration_seconds: Int?
    var rpe: Double?
    var completed: Bool
    var started_at: String?
    var completed_at: String?

    init(id: UUID = UUID(), reps: Int, weight_kg: Double, duration_seconds: Int? = nil, rpe: Double? = nil, completed: Bool, started_at: String? = nil, completed_at: String? = nil) {
        self.id = id
        self.reps = reps
        self.weight_kg = weight_kg
        self.duration_seconds = duration_seconds
        self.rpe = rpe
        self.completed = completed
        self.started_at = started_at
        self.completed_at = completed_at
    }
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
    var targetDurationSeconds: Int?
    var targetCardio: TargetCardio?
    var restSeconds: Int
    var transitionRestSeconds: Int
    var notes: String
    var coaching: ExerciseCoaching?
    var sets: [LiveSet]
    var cardioData: CardioData?
    var exerciseNotes: String
    var startedAt: String?

    var completedSets: Int { sets.filter(\.completed).count }

    var isComplete: Bool {
        if type == "cardio" {
            return (cardioData?.duration_minutes ?? 0) > 0
        }
        return completedSets >= sets.count && sets.count > 0
    }
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
    var exerciseTimes: [String: Int] = [:]

    var warmupItems: [LiveChecklistItem] = []
    var cooldownItems: [LiveChecklistItem] = []
    var journalText: String = ""

    private var nextId = 1
    private var draftTimer: Timer?

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
        exerciseTimes = [:]
        journalText = ""

        if let plan {
            exercises = plan.exercises.map { pe in
                let exType = pe.type ?? "strength"
                let sets = (0..<pe.sets).map { _ in
                    LiveSet(reps: 0, weight_kg: pe.target_weight_kg ?? 0, duration_seconds: pe.target_duration_seconds, completed: false)
                }
                return LiveExercise(
                    id: genId(),
                    order: pe.order,
                    name: pe.name,
                    type: exType,
                    planned: true,
                    targetSets: pe.sets,
                    targetReps: pe.target_reps ?? "",
                    targetWeight: pe.target_weight_kg ?? 0,
                    targetDurationSeconds: pe.target_duration_seconds,
                    targetCardio: pe.target_cardio,
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
        let newElapsed = Int(Date().timeIntervalSince(start))
        let delta = newElapsed - elapsedSeconds
        if let currentId = currentExerciseId, delta > 0 {
            if let ex = exercises.first(where: { $0.id == currentId }), ex.startedAt != nil {
                exerciseTimes[currentId, default: 0] += delta
            }
        }
        elapsedSeconds = newElapsed
    }

    func startExercise(_ exerciseId: String) {
        currentExerciseId = exerciseId
        if let idx = exercises.firstIndex(where: { $0.id == exerciseId }),
           exercises[idx].startedAt == nil {
            exercises[idx].startedAt = DateUtils.iso8601Basic.string(from: Date())
        }
        scheduleDraftSave()
    }

    func startSet(exerciseId: String, setIndex: Int) {
        guard let idx = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        guard setIndex < exercises[idx].sets.count else { return }
        exercises[idx].sets[setIndex].started_at = DateUtils.iso8601Basic.string(from: Date())
        scheduleDraftSave()
    }

    func completeSet(exerciseId: String, setIndex: Int, reps: Int, weight: Double, duration: Int? = nil, rpe: Double?) {
        guard let idx = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        guard setIndex < exercises[idx].sets.count else { return }
        exercises[idx].sets[setIndex].reps = reps
        exercises[idx].sets[setIndex].weight_kg = weight
        if let duration = duration {
            exercises[idx].sets[setIndex].duration_seconds = duration
        }
        exercises[idx].sets[setIndex].rpe = rpe
        exercises[idx].sets[setIndex].completed = true
        exercises[idx].sets[setIndex].completed_at = DateUtils.iso8601Basic.string(from: Date())
        scheduleDraftSave()
    }

    func addSet(to exerciseId: String) {
        guard let idx = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        let weight = exercises[idx].targetWeight
        let duration = exercises[idx].targetDurationSeconds
        exercises[idx].sets.append(LiveSet(reps: 0, weight_kg: weight, duration_seconds: duration, completed: false))
        scheduleDraftSave()
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
        let isDuration = type == "duration"
        let order = exercises.count + 1
        let sets: [LiveSet] = isCardio ? [] : (0..<3).map { _ in
            LiveSet(reps: 0, weight_kg: 0, duration_seconds: isDuration ? 30 : nil, completed: false)
        }
        exercises.append(LiveExercise(
            id: genId(),
            order: order,
            name: name,
            type: type,
            planned: false,
            targetSets: isCardio ? 1 : 3,
            targetReps: isCardio ? "" : (isDuration ? "30秒" : "10-12"),
            targetWeight: 0,
            targetDurationSeconds: isDuration ? 30 : nil,
            targetCardio: nil,
            restSeconds: 90,
            transitionRestSeconds: 90,
            notes: "",
            sets: sets,
            cardioData: isCardio ? CardioData(duration_minutes: 0) : nil,
            exerciseNotes: ""
        ))
    }

    func moveExercise(from source: IndexSet, to destination: Int) {
        guard let fromIdx = source.first else { return }
        let item = exercises.remove(at: fromIdx)
        let toIdx = destination > fromIdx ? destination - 1 : destination
        exercises.insert(item, at: min(toIdx, exercises.count))
        for i in exercises.indices {
            exercises[i].order = i + 1
        }
        scheduleDraftSave()
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

    func endWorkout() {
        guard let start = startTimestamp else { return }
        elapsedSeconds = Int(Date().timeIntervalSince(start))
        active = false
        LiveActivityManager.shared.stopTimer()

        let snapshot = WorkoutSnapshot(
            plan: plan,
            exercises: exercises,
            startTime: startTime,
            elapsedSeconds: elapsedSeconds,
            currentExerciseId: currentExerciseId,
            exerciseTimes: exerciseTimes,
            warmupItems: warmupItems,
            cooldownItems: cooldownItems,
            journalText: journalText
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: "finished_workout_snapshot")
        }
    }

    func restoreFromSnapshot() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "finished_workout_snapshot"),
              let snapshot = try? JSONDecoder().decode(WorkoutSnapshot.self, from: data) else { return false }
        plan = snapshot.plan
        exercises = snapshot.exercises
        startTime = snapshot.startTime
        elapsedSeconds = snapshot.elapsedSeconds
        currentExerciseId = snapshot.currentExerciseId
        exerciseTimes = snapshot.exerciseTimes
        warmupItems = snapshot.warmupItems
        cooldownItems = snapshot.cooldownItems
        journalText = snapshot.journalText
        return true
    }

    func clearSnapshot() {
        UserDefaults.standard.removeObject(forKey: "finished_workout_snapshot")
    }

    func buildResult(feeling: Int, journal: String, sleepHours: Double) -> ResultJSON {
        let now = Date()
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let endTime = timeFmt.string(from: now)
        let today = DateUtils.dateOnly.string(from: now)

        let resultExercises: [ResultExercise] = exercises.map { ex in
            if ex.type == "strength" || ex.type == "duration" || ex.type == "core" {
                let completedSets = ex.sets.filter(\.completed).map { s in
                    StrengthSet(
                        reps: s.reps,
                        weight_kg: s.weight_kg,
                        duration_seconds: s.duration_seconds,
                        rpe: s.rpe,
                        started_at: s.started_at,
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
        exerciseTimes = [:]
        warmupItems = []
        cooldownItems = []
        journalText = ""
        LiveActivityManager.shared.stopTimer()
        clearDraft()
        clearSnapshot()
    }

    // MARK: - Draft Persistence

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
            planDate: plan?.date,
            planMuscles: plan?.target_muscles.joined(separator: " + "),
            exerciseTimes: exerciseTimes,
            elapsedSeconds: elapsedSeconds,
            currentExerciseId: currentExerciseId
        )
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: Self.draftKey)
        }
    }

    @discardableResult
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
        exerciseTimes = draft.exerciseTimes
        currentExerciseId = draft.currentExerciseId
        if let start = startTimestamp {
            elapsedSeconds = Int(Date().timeIntervalSince(start))
        }

        let maxId = exercises.compactMap { ex -> Int? in
            guard let range = ex.id.range(of: #"^ex-(\d+)$"#, options: .regularExpression) else { return nil }
            let numStr = ex.id[range].replacingOccurrences(of: "ex-", with: "")
            return Int(numStr)
        }.max() ?? 0
        if maxId >= nextId { nextId = maxId + 1 }

        return true
    }

    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: Self.draftKey)
        draftTimer?.invalidate()
        draftTimer = nil
    }

    private func scheduleDraftSave() {
        draftTimer?.invalidate()
        draftTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            self?.saveDraft()
        }
    }

    // MARK: - Computed Properties

    var elapsedFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var totalCompletedSets: Int {
        exercises.reduce(0) { $0 + $1.completedSets }
    }

    var maxWeight: Double {
        exercises.flatMap { $0.sets.filter(\.completed).map(\.weight_kg) }.max() ?? 0
    }

    var draftInfo: (muscles: String, exerciseCount: Int, elapsed: Int)? {
        guard let data = UserDefaults.standard.data(forKey: Self.draftKey),
              let draft = try? JSONDecoder().decode(WorkoutDraft.self, from: data),
              draft.active, !draft.exercises.isEmpty else { return nil }
        let elapsed: Int
        if let start = draft.startTimestamp {
            elapsed = Int(Date().timeIntervalSince(start))
        } else {
            elapsed = draft.elapsedSeconds
        }
        let muscles = draft.planMuscles ?? "自由训练"
        return (muscles: muscles, exerciseCount: draft.exercises.count, elapsed: elapsed)
    }
}

// MARK: - Snapshot for Finish Page

struct WorkoutSnapshot: Codable {
    let plan: PlanJSON?
    let exercises: [LiveExercise]
    let startTime: String?
    let elapsedSeconds: Int
    let currentExerciseId: String?
    let exerciseTimes: [String: Int]
    let warmupItems: [LiveChecklistItem]
    let cooldownItems: [LiveChecklistItem]
    let journalText: String
}
