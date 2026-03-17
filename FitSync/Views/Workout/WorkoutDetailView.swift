import SwiftUI

struct WorkoutDetailView: View {
    let workout: ResultJSON

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryHeader

                if let warmup = workout.warmup_result, !warmup.isEmpty {
                    checklistSection("热身", items: warmup)
                }

                exerciseList

                if let cooldown = workout.cooldown_result, !cooldown.isEmpty {
                    checklistSection("拉伸", items: cooldown)
                }

                if !workout.journal.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("训练随笔").font(.headline)
                        Text(workout.journal)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle(workout.date)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                statItem("\(workout.duration_minutes)", label: "分钟")
                statItem("\(workout.exercises.count)", label: "动作")
                statItem("\(totalSets)", label: "组")
                statItem("评分 \(workout.overall_feeling)", label: "")
            }

            HStack(spacing: 16) {
                Label("\(workout.start_time) – \(workout.end_time)", systemImage: "clock")
                Label("睡眠 \(String(format: "%.1f", workout.sleep_hours))h", systemImage: "bed.double")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statItem(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            if !label.isEmpty { Text(label).font(.caption2).foregroundStyle(.secondary) }
        }
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + ($1.sets?.count ?? 0) }
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("训练内容").font(.headline)

            ForEach(Array(workout.exercises.enumerated()), id: \.offset) { _, ex in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(ex.name).font(.subheadline.bold())
                        if !ex.planned {
                            Text("追加").font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.orange.opacity(0.2), in: Capsule())
                        }
                        Spacer()
                        Text(ex.type == "cardio" ? "有氧" : "力量")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    if let sets = ex.sets, !sets.isEmpty {
                        ForEach(Array(sets.enumerated()), id: \.offset) { idx, set in
                            HStack {
                                Text("第 \(idx + 1) 组").font(.caption).foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .leading)
                                Text("\(set.weight_kg, specifier: "%.1f")kg × \(set.reps)")
                                    .font(.caption.monospacedDigit())
                                if let rpe = set.rpe {
                                    Text("RPE \(rpe, specifier: "%.0f")")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }

                    if let cardio = ex.cardio_data {
                        HStack(spacing: 12) {
                            if let spd = cardio.speed_kmh { Text("\(spd, specifier: "%.1f") km/h").font(.caption) }
                            Text("\(cardio.duration_minutes, specifier: "%.0f") 分钟").font(.caption)
                            if let dist = cardio.distance_km { Text("\(dist, specifier: "%.1f") km").font(.caption) }
                            if let inc = cardio.incline_pct { Text("坡度 \(inc, specifier: "%.0f")%").font(.caption) }
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let notes = ex.notes, !notes.isEmpty {
                        Text(notes).font(.caption).foregroundStyle(.secondary).italic()
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func checklistSection(_ title: String, items: [ChecklistResult]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack {
                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.done ? .green : .secondary)
                    Text(item.action).font(.subheadline)
                }
            }
        }
    }
}
