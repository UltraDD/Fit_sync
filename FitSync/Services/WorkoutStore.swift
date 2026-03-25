import Foundation

@MainActor
final class WorkoutStore {
    static let shared = WorkoutStore()

    private let fileManager = FileManager.default
    private var storageURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("workout_history.json")
    }

    private(set) var history: [ResultJSON] = []

    private init() {
        load()
    }

    func save(_ result: ResultJSON) {
        if let idx = history.firstIndex(where: { $0.date == result.date && $0.start_time == result.start_time }) {
            history[idx] = result
        } else {
            history.insert(result, at: 0)
        }
        if history.count > 200 { history = Array(history.prefix(200)) }
        persist()
    }

    func lastWorkout() -> ResultJSON? {
        history.first
    }

    func workouts(for month: String) -> [ResultJSON] {
        history.filter { $0.date.hasPrefix(month) }
    }

    func deleteWorkout(at index: Int) {
        guard index < history.count else { return }
        history.remove(at: index)
        persist()
    }

    private func load() {
        guard fileManager.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ResultJSON].self, from: data) else { return }
        history = decoded.sorted { $0.date > $1.date || ($0.date == $1.date && $0.start_time > $1.start_time) }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    func recentExerciseNames(limit: Int = 20) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for workout in history {
            for ex in workout.exercises {
                if !seen.contains(ex.name) {
                    seen.insert(ex.name)
                    result.append(ex.name)
                    if result.count >= limit { return result }
                }
            }
        }
        return result
    }
}
