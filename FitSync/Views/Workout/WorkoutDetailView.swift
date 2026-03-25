import SwiftUI

struct WorkoutDetailView: View {
    let workout: ResultJSON

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryHeader

                if let warmup = workout.warmup_result, !warmup.isEmpty {
                    checklistSection("热身", items: warmup, accentColor: .orange)
                }

                exerciseList

                if let cooldown = workout.cooldown_result, !cooldown.isEmpty {
                    checklistSection("拉伸", items: cooldown, accentColor: .blue)
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
            HStack(spacing: 0) {
                statItem("\(workout.duration_minutes)", label: "分钟")
                Spacer()
                statItem("\(workout.exercises.count)", label: "动作")
                Spacer()
                statItem("\(totalSets)", label: "组")
                Spacer()
            }

            HStack(spacing: 16) {
                Label("\(workout.start_time) – \(workout.end_time)", systemImage: "clock")
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
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + ($1.sets?.count ?? 0) }
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("训练内容").font(.headline)

            ForEach(workout.exercises) { ex in
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
                        ForEach(Array(sets.enumerated()), id: \.element.id) { idx, s in
                            HStack {
                                Text("第 \(idx + 1) 组")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .leading)
                                if let duration = s.duration_seconds {
                                    Text("\(duration)秒")
                                        .font(.caption.monospacedDigit())
                                } else {
                                    let weight = s.weight_kg ?? 0
                                    let reps = s.reps ?? 0
                                    Text("\(String(format: "%.1f", weight))kg × \(reps)")
                                        .font(.caption.monospacedDigit())
                                }
                                if let rpe = s.rpe {
                                    Text("RPE \(String(format: "%.0f", rpe))")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }

                    if let cardio = ex.cardio_data {
                        HStack(spacing: 12) {
                            if let spd = cardio.speed_kmh {
                                Text("\(String(format: "%.1f", spd)) km/h").font(.caption)
                            }
                            Text("\(Int(cardio.duration_minutes)) 分钟").font(.caption)
                            if let dist = cardio.distance_km {
                                Text("\(String(format: "%.1f", dist)) km").font(.caption)
                            }
                            if let inc = cardio.incline_pct {
                                Text("坡度 \(String(format: "%.0f", inc))%").font(.caption)
                            }
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

    private func checklistSection(_ title: String, items: [ChecklistResult], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(items) { item in
                HStack {
                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.done ? accentColor : .secondary)
                    Text(item.action).font(.subheadline)
                }
            }
        }
    }
}
