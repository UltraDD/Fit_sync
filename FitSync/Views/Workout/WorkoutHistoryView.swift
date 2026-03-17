import SwiftUI

struct WorkoutHistoryView: View {
    @State private var history: [ResultJSON] = []

    private var groupedByMonth: [(String, [ResultJSON])] {
        let grouped = Dictionary(grouping: history) { result in
            String(result.date.prefix(7))
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        List {
            if history.isEmpty {
                ContentUnavailableView("暂无训练记录", systemImage: "dumbbell", description: Text("完成一次训练后，记录会出现在这里"))
            } else {
                ForEach(groupedByMonth, id: \.0) { month, workouts in
                    Section(formatMonth(month)) {
                        ForEach(Array(workouts.enumerated()), id: \.offset) { _, workout in
                            NavigationLink {
                                WorkoutDetailView(workout: workout)
                            } label: {
                                workoutRow(workout)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("训练历史")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { history = WorkoutStore.shared.history }
    }

    private func workoutRow(_ w: ResultJSON) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(w.date)
                    .font(.subheadline.bold())
                Spacer()
                Text(feelingEmoji(w.overall_feeling))
                    .font(.caption)
            }
            HStack(spacing: 12) {
                Label("\(w.exercises.count) 动作", systemImage: "figure.strengthtraining.traditional")
                Label("\(w.duration_minutes) 分钟", systemImage: "clock")
                if let maxW = maxWeight(w) {
                    Label(String(format: "%.1fkg", maxW), systemImage: "scalemass")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func maxWeight(_ w: ResultJSON) -> Double? {
        var best: Double = 0
        for ex in w.exercises {
            for s in (ex.sets ?? []) where s.weight_kg > best {
                best = s.weight_kg
            }
        }
        return best > 0 ? best : nil
    }

    private func feelingEmoji(_ score: Int) -> String {
        switch score {
        case 1...3: return "😣 \(score)"
        case 4...5: return "😐 \(score)"
        case 6...7: return "🙂 \(score)"
        case 8...9: return "💪 \(score)"
        case 10: return "🔥 \(score)"
        default: return "\(score)"
        }
    }

    private func formatMonth(_ ym: String) -> String {
        let parts = ym.split(separator: "-")
        guard parts.count == 2 else { return ym }
        return "\(parts[0]) 年 \(Int(parts[1]) ?? 0) 月"
    }
}
