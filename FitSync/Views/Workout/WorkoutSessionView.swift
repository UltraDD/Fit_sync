import SwiftUI

struct WorkoutSessionView: View {
    @Bindable var workoutState: WorkoutState
    var homeVM: HomeViewModel
    @State private var showJournal = false
    @State private var showAddExercise = false
    @State private var showEndConfirm = false
    @State private var navigateToFinish = false
    @State private var timer: Timer?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let notes = workoutState.plan?.coach_notes, !notes.isEmpty {
                Section {
                    Text(notes).font(.subheadline).foregroundStyle(.secondary)
                } header: {
                    Label("教练备注", systemImage: "note.text")
                }
            }

            if !workoutState.warmupItems.isEmpty {
                Section("热身") {
                    ForEach(Array(workoutState.warmupItems.enumerated()), id: \.offset) { index, item in
                        Button {
                            workoutState.toggleWarmup(at: index)
                        } label: {
                            HStack {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.done ? .green : .secondary)
                                VStack(alignment: .leading) {
                                    Text(item.action)
                                    if let detail = item.detail {
                                        Text(detail).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
            }

            Section("动作") {
                ForEach(workoutState.exercises) { exercise in
                    NavigationLink {
                        ExerciseDetailView(workoutState: workoutState, exerciseId: exercise.id)
                    } label: {
                        exerciseRow(exercise)
                    }
                }
                .onMove { from, to in
                    guard let fromIdx = from.first else { return }
                    workoutState.moveExercise(from: fromIdx, to: to)
                }
            }

            if !workoutState.cooldownItems.isEmpty {
                Section("拉伸") {
                    ForEach(Array(workoutState.cooldownItems.enumerated()), id: \.offset) { index, item in
                        Button {
                            workoutState.toggleCooldown(at: index)
                        } label: {
                            HStack {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.done ? .green : .secondary)
                                VStack(alignment: .leading) {
                                    Text(item.action)
                                    if let detail = item.detail {
                                        Text(detail).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
        }
        .navigationTitle(workoutState.plan?.target_muscles.joined(separator: " + ") ?? "自由训练")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(workoutState.elapsedFormatted)
                    .font(.headline.monospacedDigit())
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button { showJournal = true } label: {
                    Image(systemName: "note.text")
                }
                Spacer()
                Button("结束训练") { showEndConfirm = true }
                    .tint(.red)
                Spacer()
                Button { showAddExercise = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .tint(.green)
            }
        }
        .alert("确认结束训练？", isPresented: $showEndConfirm) {
            Button("取消", role: .cancel) {}
            Button("结束", role: .destructive) {
                navigateToFinish = true
            }
        } message: {
            Text("将进入训练总结页面")
        }
        .sheet(isPresented: $showJournal) {
            NavigationStack {
                TextEditor(text: Binding(
                    get: { workoutState.journalText },
                    set: { workoutState.journalText = $0 }
                ))
                .padding()
                .navigationTitle("训练随笔")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showJournal = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddExercise) {
            AddExerciseSheet(workoutState: workoutState)
        }
        .navigationDestination(isPresented: $navigateToFinish) {
            WorkoutFinishView(workoutState: workoutState, homeVM: homeVM)
        }
        .onChange(of: workoutState.active) { _, newValue in
            if !newValue { dismiss() }
        }
        .onAppear {
            startTimer()
            if workoutState.exercises.isEmpty {
                showAddExercise = true
            }
        }
        .onChange(of: workoutState.elapsedSeconds) { _, newValue in
            if newValue == 10800 {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
        .onDisappear { timer?.invalidate() }
        .toolbar(.hidden, for: .tabBar)
    }

    private func exerciseRow(_ exercise: LiveExercise) -> some View {
        HStack {
            if exercise.isComplete {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if exercise.startedAt != nil {
                Image(systemName: "circle.fill").foregroundStyle(.green).font(.caption)
            } else {
                Image(systemName: "circle").foregroundStyle(.secondary)
            }
            VStack(alignment: .leading) {
                HStack {
                    Text(exercise.name).font(.body)
                    if !exercise.planned {
                        Text("追加").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.orange.opacity(0.2), in: Capsule())
                    }
                }
                if exercise.type == "strength" {
                    Text("\(exercise.completedSets)/\(exercise.targetSets) 组 · \(exercise.targetWeight, specifier: "%.1f")kg")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("有氧").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            workoutState.tick()
        }
    }
}
