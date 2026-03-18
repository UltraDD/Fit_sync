import SwiftUI

struct WorkoutSessionView: View {
    @Bindable var workoutState: WorkoutState
    var homeVM: HomeViewModel
    @State private var showJournal = false
    @State private var showAddExercise = false
    @State private var batchMode = false
    @State private var navigateToFinish = false
    @State private var showTimerSheet = false
    @State private var sortMode = false
    @State private var timer: Timer?
    @State private var selectedExerciseId: String?
    @State private var navigateToExercise = false
    @Environment(\.dismiss) private var dismiss

    @State private var confirmEnd = false
    @State private var confirmReady = false

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()

            ScrollView {
                VStack(spacing: 12) {
                    if workoutState.elapsedSeconds >= 10800 {
                        warningBanner
                    }

                    if let notes = workoutState.plan?.coach_notes, !notes.isEmpty {
                        coachNotesView(notes)
                    }

                    if !workoutState.warmupItems.isEmpty {
                        checklistSection(
                            icon: "sun.max.fill",
                            label: "热身",
                            items: workoutState.warmupItems,
                            toggle: { workoutState.toggleWarmup(at: $0) },
                            accent: FLColor.amber,
                            accentLight: FLColor.amberLight
                        )
                    }

                    exerciseList

                    if workoutState.exercises.isEmpty {
                        emptyState
                    }

                    if !workoutState.cooldownItems.isEmpty {
                        checklistSection(
                            icon: "snowflake",
                            label: "拉伸",
                            items: workoutState.cooldownItems,
                            toggle: { workoutState.toggleCooldown(at: $0) },
                            accent: FLColor.sky,
                            accentLight: FLColor.sky
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 130)
            }

            bottomBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button { showTimerSheet = true } label: {
                    Text(workoutState.elapsedFormatted)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if workoutState.exercises.count > 1 {
                    Button {
                        sortMode.toggle()
                    } label: {
                        Text(sortMode ? "完成" : "排序")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(sortMode ? FLColor.sky : FLColor.text50)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $navigateToFinish) {
            WorkoutFinishView(workoutState: workoutState, homeVM: homeVM)
        }
        .navigationDestination(isPresented: $navigateToExercise) {
            if let id = selectedExerciseId {
                ExerciseDetailView(workoutState: workoutState, exerciseId: id)
            }
        }
        .sheet(isPresented: $showJournal) { journalSheet }
        .sheet(isPresented: $showAddExercise) {
            AddExerciseSheet(workoutState: workoutState, batchMode: batchMode)
        }
        .sheet(isPresented: $showTimerSheet) { timerDetailSheet }
        .onAppear {
            startTimer()
            if workoutState.exercises.isEmpty && workoutState.plan == nil {
                batchMode = true
                showAddExercise = true
            }
        }
        .onChange(of: workoutState.elapsedSeconds) { _, newValue in
            if newValue == 10800 {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
        .onDisappear {
            timer?.invalidate()
            workoutState.saveDraft()
        }
    }

    // MARK: - Warning

    private var warningBanner: some View {
        Text("⚠️ 已训练超过 3 小时，注意休息和补水")
            .font(.subheadline)
            .foregroundStyle(FLColor.amberLight.opacity(0.8))
            .frame(maxWidth: .infinity)
            .glassCard(padding: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(FLColor.amber.opacity(0.2), lineWidth: 1)
            )
    }

    // MARK: - Coach Notes

    private func coachNotesView(_ notes: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("🗣️")
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(FLColor.amberLight.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 16)
    }

    // MARK: - Checklist

    private func checklistSection(icon: String, label: String, items: [LiveChecklistItem], toggle: @escaping (Int) -> Void, accent: Color, accentLight: Color) -> some View {
        let allDone = items.allSatisfy(\.done)
        let doneCount = items.filter(\.done).count

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(accentLight.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(accent.opacity(0.10), in: Circle())
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundStyle(accentLight.opacity(0.8))
                Spacer()
                Text("\(doneCount)/\(items.count)")
                    .font(.caption).foregroundStyle(FLColor.text40)
            }

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    toggle(index)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(item.done ? accent.opacity(0.2) : Color.clear)
                            .overlay(
                                Circle().strokeBorder(item.done ? Color.clear : FLColor.text20, lineWidth: 1)
                            )
                            .overlay(
                                item.done ? Image(systemName: "checkmark")
                                    .font(.caption2.bold())
                                    .foregroundStyle(accent) : nil
                            )
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.action)
                                .font(.subheadline)
                                .strikethrough(item.done)
                                .foregroundStyle(item.done ? FLColor.text40 : .white)
                            if let detail = item.detail {
                                Text(detail).font(.caption).foregroundStyle(FLColor.text30)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        item.done ? Color.clear : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        item.done ? nil :
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(FLColor.cardBorder, lineWidth: 1)
                    )
                    .opacity(item.done ? 0.6 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .glassCard(padding: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(accentLight.opacity(0.2), lineWidth: 1)
        )
        .opacity(allDone ? 0.6 : 1)
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        Group {
            if sortMode {
                List {
                    ForEach(workoutState.exercises) { exercise in
                        exerciseRow(exercise)
                    }
                    .onMove { from, to in
                        workoutState.moveExercise(from: from, to: to)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(workoutState.exercises.count * 72))
                .environment(\.editMode, .constant(.active))
            } else {
                ForEach(workoutState.exercises) { exercise in
                    Button {
                        selectedExerciseId = exercise.id
                        navigateToExercise = true
                    } label: {
                        exerciseCard(exercise)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func exerciseCard(_ exercise: LiveExercise) -> some View {
        let completedCount = exercise.type == "strength"
            ? exercise.sets.filter(\.completed).count
            : ((exercise.cardioData?.duration_minutes ?? 0) > 0 ? 1 : 0)
        let totalCount = exercise.type == "strength" ? exercise.sets.count : 1
        let isDone = completedCount >= totalCount && totalCount > 0
        let isCurrent = exercise.id == workoutState.currentExerciseId
        let maxW = exercise.type == "strength"
            ? exercise.sets.filter(\.completed).map(\.weight_kg).max() ?? 0
            : 0

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isDone ? FLColor.green.opacity(0.2) : isCurrent ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                    .frame(width: 28, height: 28)
                if isDone {
                    Image(systemName: "checkmark").font(.caption2.bold()).foregroundStyle(FLColor.green)
                } else {
                    Text("\(exercise.order)")
                        .font(.caption.bold())
                        .foregroundStyle(isCurrent ? .white : FLColor.text30)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.body.weight(.semibold))
                        .strikethrough(isDone)
                        .foregroundStyle(isDone ? FLColor.text40 : .white)
                    if !exercise.planned {
                        Text("追加")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(FLColor.sky.opacity(0.2), in: Capsule())
                            .foregroundStyle(FLColor.sky)
                    }
                }
                HStack(spacing: 8) {
                    if exercise.type == "strength" {
                        Text("\(completedCount)/\(totalCount) 组")
                            .font(.caption).foregroundStyle(FLColor.text40)
                        if maxW > 0 {
                            Text("最大 \(String(format: "%.1f", maxW))kg")
                                .font(.caption).foregroundStyle(FLColor.text40)
                        }
                    } else {
                        if let cd = exercise.cardioData, cd.duration_minutes > 0 {
                            Text("\(Int(cd.duration_minutes))分钟")
                                .font(.caption).foregroundStyle(FLColor.text40)
                        } else {
                            Text("有氧 · 待记录")
                                .font(.caption).foregroundStyle(FLColor.text40)
                        }
                    }
                }
            }

            Spacer()

            if isCurrent {
                Circle()
                    .fill(FLColor.green)
                    .frame(width: 8, height: 8)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(FLColor.text20)
        }
        .glassCard(highlight: isCurrent, padding: 16)
        .opacity(isDone ? 0.5 : 1)
    }

    private func exerciseRow(_ exercise: LiveExercise) -> some View {
        HStack {
            Text(exercise.name).font(.body).foregroundStyle(.white)
            Spacer()
            Text("\(exercise.completedSets)/\(exercise.sets.count) 组")
                .font(.caption).foregroundStyle(FLColor.text40)
        }
        .listRowBackground(Color.white.opacity(0.05))
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("空空如也").font(.headline).foregroundStyle(FLColor.text40)
            Text("点击下方 + 添加训练动作").font(.subheadline).foregroundStyle(FLColor.text30)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                showJournal.toggle()
            } label: {
                Image(systemName: showJournal ? "note.text.badge.plus" : "note.text")
                    .font(.title3)
                    .foregroundStyle(FLColor.text60)
                    .frame(width: 44, height: 44)
            }

            if !confirmEnd {
                Button {
                    confirmEnd = true
                    confirmReady = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        confirmReady = true
                    }
                } label: {
                    Text("结束训练")
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Button {
                    guard confirmReady else { return }
                    handleEndWorkout()
                } label: {
                    Text(confirmReady ? "确认结束训练" : "等待确认（2s）")
                }
                .buttonStyle(DangerButtonStyle())
                .disabled(!confirmReady)
                .opacity(confirmReady ? 1 : 0.6)
            }

            Button {
                batchMode = false
                showAddExercise = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundStyle(.black)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            colors: [FLColor.green, FLColor.greenDark],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: FLColor.greenDark.opacity(0.25), radius: 8, y: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            FLColor.bg.opacity(0.8)
                .background(.ultraThinMaterial)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
        }
    }

    // MARK: - Journal

    private var journalSheet: some View {
        NavigationStack {
            ZStack {
                FLColor.bg.ignoresSafeArea()
                TextEditor(text: Binding(
                    get: { workoutState.journalText },
                    set: { workoutState.journalText = $0 }
                ))
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .padding()
            }
            .navigationTitle("训练随笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showJournal = false }
                        .foregroundStyle(FLColor.green)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Timer Detail

    private var timerDetailSheet: some View {
        NavigationStack {
            ZStack {
                FLColor.bg.ignoresSafeArea()
                List {
                    Section {
                        HStack {
                            Text("总用时").font(.headline).foregroundStyle(.white)
                            Spacer()
                            Text(workoutState.elapsedFormatted)
                                .font(.title2.bold().monospacedDigit())
                                .foregroundStyle(.white)
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    Section("动作用时") {
                        ForEach(workoutState.exercises) { ex in
                            let t = workoutState.exerciseTimes[ex.id] ?? 0
                            HStack {
                                Text(ex.name).font(.subheadline).foregroundStyle(.white)
                                Spacer()
                                Text(formatTime(t))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(FLColor.text40)
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("训练用时详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showTimerSheet = false }
                        .foregroundStyle(FLColor.green)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers

    private func handleEndWorkout() {
        workoutState.endWorkout()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            navigateToFinish = true
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            workoutState.tick()
        }
    }

    private func formatTime(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }
}
