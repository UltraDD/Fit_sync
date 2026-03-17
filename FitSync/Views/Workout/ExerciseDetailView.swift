import SwiftUI

struct ExerciseDetailView: View {
    @Bindable var workoutState: WorkoutState
    let exerciseId: String
    @State private var showRestTimer = false
    @State private var restSeconds: Int = 120
    @State private var showCoaching = false
    @State private var repsInput: Int = 10
    @State private var showRepsSheet = false
    @State private var completedSetIndex: Int = 0
    @State private var currentWeight: Double = 0
    @State private var cardioIncline: Double = 0
    @State private var cardioSpeed: Double = 6
    @State private var cardioDuration: Double = 20
    @State private var cardioDistance: Double = 0
    @Environment(\.dismiss) private var dismiss

    private var exercise: LiveExercise? {
        workoutState.exercises.first { $0.id == exerciseId }
    }

    var body: some View {
        if let exercise {
            ScrollView {
                VStack(spacing: 20) {
                    if let coaching = exercise.coaching {
                        coachingSection(coaching)
                    }

                    if !exercise.notes.isEmpty {
                        Text(exercise.notes)
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    if exercise.type == "strength" {
                        strengthView(exercise)
                    } else {
                        cardioView(exercise)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注").font(.caption).foregroundStyle(.secondary)
                        TextField("记录感受...", text: Binding(
                            get: { exercise.exerciseNotes },
                            set: { workoutState.updateExerciseNotes(exerciseId: exerciseId, notes: $0) }
                        ), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showRestTimer) {
                RestTimerView(seconds: restSeconds, exerciseName: exercise.name,
                             setInfo: "第 \(completedSetIndex + 1)/\(exercise.targetSets) 组完成",
                             nextInfo: "下一组目标：\(String(format: "%.1f", exercise.targetWeight))kg × \(exercise.targetReps)")
            }
            .sheet(isPresented: $showRepsSheet) {
                repsInputSheet(exercise)
            }
            .onAppear {
                workoutState.startExercise(exerciseId)
                repsInput = Int(exercise.targetReps.components(separatedBy: "-").last ?? "10") ?? 10
                currentWeight = exercise.targetWeight
                if let cardio = exercise.cardioData {
                    cardioIncline = cardio.incline_pct ?? 0
                    cardioSpeed = cardio.speed_kmh ?? 6
                    cardioDuration = cardio.duration_minutes
                    cardioDistance = cardio.distance_km ?? 0
                }
            }
        }
    }

    private func coachingSection(_ coaching: ExerciseCoaching) -> some View {
        DisclosureGroup("动作教学", isExpanded: $showCoaching) {
            VStack(alignment: .leading, spacing: 12) {
                if let setup = coaching.setup { coachingItem("起始姿势", setup) }
                if let execution = coaching.execution { coachingItem("动作过程", execution) }
                if let breathing = coaching.breathing { coachingItem("呼吸", breathing) }
                if let tips = coaching.tips, !tips.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("提示").font(.caption.bold()).foregroundStyle(.blue)
                        ForEach(tips, id: \.self) { Text("• \($0)").font(.caption) }
                    }
                }
                if let mistakes = coaching.mistakes, !mistakes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("常见错误").font(.caption.bold()).foregroundStyle(.red)
                        ForEach(mistakes, id: \.self) { Text($0).font(.caption) }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func coachingItem(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            Text(text).font(.caption)
        }
    }

    private func strengthView(_ exercise: LiveExercise) -> some View {
        VStack(spacing: 16) {
            let nextSetIndex = exercise.sets.firstIndex { !$0.completed } ?? exercise.sets.count

            if nextSetIndex < exercise.sets.count {
                VStack(spacing: 16) {
                    Text("第 \(nextSetIndex + 1) 组").font(.headline)

                    HStack(spacing: 24) {
                        Button { currentWeight = max(0, currentWeight - 2.5) } label: {
                            Image(systemName: "minus.circle.fill").font(.title)
                        }
                        Text("\(currentWeight, specifier: "%.1f") kg")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Button { currentWeight += 2.5 } label: {
                            Image(systemName: "plus.circle.fill").font(.title)
                        }
                    }

                    Button {
                        completedSetIndex = nextSetIndex
                        showRepsSheet = true
                    } label: {
                        Text("完成本组")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            ForEach(Array(exercise.sets.enumerated().reversed()), id: \.offset) { index, set in
                if set.completed {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("第 \(index + 1) 组")
                        Spacer()
                        Text("\(set.weight_kg, specifier: "%.1f")kg × \(set.reps)")
                        if let rpe = set.rpe { Text("RPE \(rpe, specifier: "%.1f")").foregroundStyle(.secondary) }
                    }
                    .font(.subheadline)
                    .padding(.horizontal)
                }
            }

            if exercise.completedSets >= exercise.targetSets {
                Button("+ 追加一组") {
                    workoutState.addSet(to: exerciseId)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
        .onAppear { currentWeight = exercise.targetWeight }
    }

    private func repsInputSheet(_ exercise: LiveExercise) -> some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("完成次数").font(.headline)

                HStack(spacing: 24) {
                    Button { repsInput = max(1, repsInput - 1) } label: {
                        Image(systemName: "minus.circle.fill").font(.title)
                    }
                    Text("\(repsInput)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Button { repsInput += 1 } label: {
                        Image(systemName: "plus.circle.fill").font(.title)
                    }
                }

                Text("RPE 评分（可选）").font(.subheadline).foregroundStyle(.secondary)

                let rpeValues: [Double] = [6, 7, 7.5, 8, 8.5, 9, 9.5, 10]
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(rpeValues, id: \.self) { rpe in
                        Button {
                            workoutState.completeSet(exerciseId: exerciseId, setIndex: completedSetIndex, reps: repsInput, weight: currentWeight, rpe: rpe)
                            showRepsSheet = false
                            triggerRest(exerciseId: exerciseId)
                        } label: {
                            Text(rpe.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", rpe) : String(format: "%.1f", rpe))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Button("跳过 RPE") {
                    workoutState.completeSet(exerciseId: exerciseId, setIndex: completedSetIndex, reps: repsInput, weight: currentWeight, rpe: nil)
                    showRepsSheet = false
                    triggerRest(exerciseId: exerciseId)
                }
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("记录")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private func triggerRest(exerciseId: String) {
        guard let ex = workoutState.exercises.first(where: { $0.id == exerciseId }) else { return }
        let nextSetIndex = ex.sets.firstIndex { !$0.completed }
        if nextSetIndex != nil {
            restSeconds = ex.restSeconds
            showRestTimer = true
        }
    }

    private func cardioView(_ exercise: LiveExercise) -> some View {
        VStack(spacing: 20) {
            sliderRow("坡度", value: $cardioIncline, range: 0...15, step: 0.5, unit: "%")
            sliderRow("速度", value: $cardioSpeed, range: 2...20, step: 0.5, unit: "km/h")
            sliderRow("时长", value: $cardioDuration, range: 1...120, step: 1, unit: "分钟")
            sliderRow("距离（选填）", value: $cardioDistance, range: 0...30, step: 0.1, unit: "km")

            Button {
                workoutState.updateCardio(exerciseId: exerciseId, data: CardioData(
                    incline_pct: cardioIncline > 0 ? cardioIncline : nil,
                    speed_kmh: cardioSpeed > 0 ? cardioSpeed : nil,
                    duration_minutes: cardioDuration,
                    distance_km: cardioDistance > 0 ? cardioDistance : nil
                ))
                dismiss()
            } label: {
                Text("保存记录").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal)
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(value.wrappedValue, specifier: step >= 1 ? "%.0f" : "%.1f") \(unit)")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }
}
