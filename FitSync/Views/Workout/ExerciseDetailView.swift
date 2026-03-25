import SwiftUI
import Combine

struct ExerciseDetailView: View {
    @Bindable var workoutState: WorkoutState
    let exerciseId: String
    var onNavigateToNext: ((String) -> Void)?
    @State private var showCoaching = false
    @State private var currentWeight: Double = 0
    @State private var repsInput: Int = 10
    @State private var durationInput: Int = 30
    @State private var exerciseNotes: String = ""

    @State private var inputPhase: InputPhase = .idle
    @State private var pendingSetIndex: Int = 0
    @State private var editingSetIndex: Int?

    @State private var restConfig: RestConfig?
    @State private var transitionRestConfig: TransitionRestConfig?

    @State private var now = Date()

    @State private var editingWeight = false
    @State private var weightText = ""
    @State private var editingReps = false
    @State private var repsText = ""
    @State private var editingDuration = false
    @State private var durationText = ""
    @FocusState private var manualInputFocused: Bool

    @Environment(\.dismiss) private var dismiss

    enum InputPhase { case idle, repsInput, rpeSelect }

    private let secondTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    struct RestConfig {
        let seconds: Int
        let setInfo: String
    }

    struct TransitionRestConfig {
        let seconds: Int
        let nextExercise: LiveExercise
    }

    private var exercise: LiveExercise? {
        workoutState.exercises.first { $0.id == exerciseId }
    }

    var body: some View {
        if let exercise {
            exerciseContent(exercise)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(exercise.name).font(.headline)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if !exercise.planned {
                            FLBadge(text: "追加", color: FLColor.sky)
                        }
                    }
                }
                .fullScreenCover(item: $restConfig) { config in
                    RestTimerView(
                        seconds: config.seconds,
                        exerciseName: exercise.name,
                        setInfo: config.setInfo,
                        mode: .setRest
                    ) { restConfig = nil }
                }
                .fullScreenCover(item: $transitionRestConfig) { config in
                    RestTimerView(
                        seconds: config.seconds,
                        exerciseName: exercise.name,
                        setInfo: "",
                        mode: .transition,
                        nextExercise: config.nextExercise
                    ) {
                        transitionRestConfig = nil
                        navigateToNext()
                    }
                }
                .onAppear { initializeInputs(exercise) }
                .onReceive(secondTicker) { date in
                    now = date
                }
        } else {
            ContentUnavailableView("动作未找到", systemImage: "exclamationmark.triangle")
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func exerciseContent(_ exercise: LiveExercise) -> some View {
        let isStarted = exercise.startedAt != nil
            || exercise.sets.contains(where: \.completed)
            || (exercise.type == "cardio" && (exercise.cardioData?.duration_minutes ?? 0) > 0)
        let completedCount = exercise.type == "strength"
            ? exercise.sets.filter(\.completed).count
            : ((exercise.cardioData?.duration_minutes ?? 0) > 0 ? 1 : 0)
        let totalCount = exercise.type == "strength" ? exercise.sets.count : 1
        let isAllDone = completedCount >= totalCount && totalCount > 0

        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 16) {
                    if exercise.planned {
                        targetInfoCard(exercise)
                    }

                    if isStarted && exercise.type == "strength" && totalCount > 0 {
                        progressBar(exercise: exercise, completed: completedCount, total: totalCount)
                    }

                    if !isStarted {
                        beforeStartContent(exercise)
                    } else {
                        afterStartContent(exercise, isAllDone: isAllDone)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, isStarted ? 100 : 0)
            }
            .safeAreaInset(edge: .bottom) {
                if !isStarted {
                    startButton(exercise)
                } else if isAllDone {
                    bottomNavigationDone(exercise)
                } else {
                    bottomNavigationSkip(exercise)
                }
            }
        }
    }

    // MARK: - Target Info

    private func targetInfoCard(_ exercise: LiveExercise) -> some View {
        Group {
            if exercise.type == "cardio", let tc = exercise.targetCardio {
                cardioTargetCard(tc)
            } else {
                HStack(spacing: 20) {
                    if exercise.type == "strength" {
                        targetInfoItem(title: "目标重量", value: "\(formatWeight(exercise.targetWeight))", unit: "kg")
                        targetInfoItem(title: "目标组数", value: "\(exercise.targetSets)", unit: "组")
                        targetInfoItem(title: "目标次数", value: exercise.targetReps, unit: "次")
                    } else if exercise.type == "duration" || exercise.type == "core" {
                        targetInfoItem(title: "目标组数", value: "\(exercise.targetSets)", unit: "组")
                        targetInfoItem(title: "目标时长", value: "\(exercise.targetDurationSeconds ?? 30)", unit: "秒")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func cardioTargetCard(_ tc: TargetCardio) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                targetInfoItem(title: "时长", value: "\(tc.duration_minutes)", unit: "分钟")
                if let incline = tc.incline_pct {
                    targetInfoItem(title: "坡度", value: String(format: "%.0f", incline), unit: "%")
                }
                if let speed = tc.speed_kmh {
                    targetInfoItem(title: "速度", value: String(format: "%.1f", speed), unit: "km/h")
                }
            }
            if let hr = tc.target_hr_range, hr.count == 2 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(FLColor.red.opacity(0.8))
                    Text("目标心率 \(hr[0])-\(hr[1])")
                        .font(.caption)
                        .foregroundStyle(FLColor.text50)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func targetInfoItem(title: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(FLColor.text40)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.title2.bold()).foregroundStyle(.white)
                Text(unit).font(.caption).foregroundStyle(FLColor.text50)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress Bar

    private func progressBar(exercise: LiveExercise, completed: Int, total: Int) -> some View {
        let nextPendingIndex = exercise.sets.firstIndex(where: { !$0.completed })
        return HStack(spacing: 4) {
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { i, s in
                RoundedRectangle(cornerRadius: 2)
                    .fill(s.completed ? FLColor.green : i == nextPendingIndex ? Color.white.opacity(0.4) : Color.white.opacity(0.1))
                    .frame(height: 6)
            }
            Text("\(completed)/\(total)")
                .font(.caption2)
                .foregroundStyle(FLColor.text40)
                .monospacedDigit()
        }
    }

    // MARK: - Before Start

    private func beforeStartContent(_ exercise: LiveExercise) -> some View {
        VStack(spacing: 16) {
            if let coaching = exercise.coaching, CoachingCardView.hasContent(coaching) {
                CoachingCardView(coaching: coaching, collapsed: false, showDetail: $showCoaching)
            }
            if !exercise.notes.isEmpty && !CoachingCardView.hasContent(exercise.coaching) {
                notesCard(exercise.notes)
            }
        }
    }

    private func startButton(_ exercise: LiveExercise) -> some View {
        Button {
            workoutState.startExercise(exerciseId)
        } label: {
            Text("准备完毕，开始 →")
        }
        .buttonStyle(GreenButtonStyle())
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .padding(.bottom, 8)
        .background(
            FLColor.bg.opacity(0.8)
                .background(.ultraThinMaterial)
        )
    }

    // MARK: - After Start

    @ViewBuilder
    private func afterStartContent(_ exercise: LiveExercise, isAllDone: Bool) -> some View {
        if exercise.type == "strength" || exercise.type == "duration" || exercise.type == "core" {
            strengthRecorder(exercise, isAllDone: isAllDone)
        } else {
            CardioSectionView(
                workoutState: workoutState,
                exerciseId: exerciseId,
                exercise: exercise,
                now: now
            )
        }

        if let coaching = exercise.coaching, CoachingCardView.hasContent(coaching) {
            CoachingCardView(coaching: coaching, collapsed: true, showDetail: $showCoaching)
        }

        if !exercise.notes.isEmpty && !CoachingCardView.hasContent(exercise.coaching) {
            notesCard(exercise.notes)
        }

        exerciseNotesField
    }

    // MARK: - Strength Recorder

    private func strengthRecorder(_ exercise: LiveExercise, isAllDone: Bool) -> some View {
        let isDuration = exercise.type == "duration" || exercise.type == "core"
        let nextSetIndex = exercise.sets.firstIndex { !$0.completed }
        return VStack(spacing: 12) {
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { i, s in
                if s.completed && editingSetIndex != i {
                    completedSetRow(i, set: s, isDuration: isDuration)
                }
            }

            if let nextIdx = nextSetIndex, inputPhase == .idle {
                if exercise.sets[nextIdx].started_at == nil {
                    setStartButton(exercise, setIndex: nextIdx, isDuration: isDuration)
                } else {
                    currentSetInput(exercise, setIndex: nextIdx, isDuration: isDuration)
                }
            }

            if inputPhase == .repsInput {
                if isDuration {
                    durationInputView
                } else {
                    repsInputView
                }
            }
            if inputPhase == .rpeSelect {
                RPESelectorView { rpe in confirmSet(rpe: rpe) }
            }

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { i, s in
                if !s.completed && i != nextSetIndex {
                    pendingSetRow(i)
                }
            }

            if isAllDone {
                VStack(spacing: 8) {
                    Label("全部组数已完成", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(FLColor.green).font(.subheadline.bold())
                    Button("+ 追加一组") { workoutState.addSet(to: exerciseId) }
                        .font(.caption).foregroundStyle(FLColor.text40)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func completedSetRow(_ index: Int, set: LiveSet, isDuration: Bool) -> some View {
        Button {
            editingSetIndex = index
            pendingSetIndex = index
            currentWeight = set.weight_kg
            repsInput = set.reps
            durationInput = set.duration_seconds ?? 30
            inputPhase = .repsInput
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(FLColor.green)
                Text("第 \(index + 1) 组")
                    .font(.subheadline).foregroundStyle(FLColor.text40)
                Spacer()
                if isDuration {
                    Text("\(set.duration_seconds ?? 0)秒")
                        .font(.subheadline).monospacedDigit()
                } else {
                    Text("\(set.reps)次 × \(formatWeight(set.weight_kg))kg")
                        .font(.subheadline).monospacedDigit()
                }
                if let rpe = set.rpe {
                    Text("RPE \(String(format: "%.0f", rpe))")
                        .font(.caption).foregroundStyle(FLColor.text30)
                }
                Image(systemName: "pencil")
                    .font(.caption2).foregroundStyle(FLColor.text20)
            }
            .glassCard(padding: 16)
            .opacity(0.5)
        }
        .buttonStyle(.plain)
    }

    private func setStartButton(_ exercise: LiveExercise, setIndex: Int, isDuration: Bool) -> some View {
        VStack(spacing: 14) {
            Text("第 \(setIndex + 1) 组")
                .font(.headline)

            if exercise.planned {
                if isDuration {
                    Text("目标：\(exercise.targetDurationSeconds ?? 30) 秒")
                        .font(.subheadline).foregroundStyle(FLColor.text40)
                } else {
                    Text("目标：\(formatWeight(exercise.targetWeight))kg × \(exercise.targetReps)")
                        .font(.subheadline).foregroundStyle(FLColor.text40)
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                workoutState.startSet(exerciseId: exerciseId, setIndex: setIndex)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("开始本组")
                }
            }
            .buttonStyle(GreenButtonStyle())
        }
        .glassCard(highlight: true)
    }

    private func currentSetInput(_ exercise: LiveExercise, setIndex: Int, isDuration: Bool) -> some View {
        VStack(spacing: 16) {
            Text("第 \(setIndex + 1) 组（当前）")
                .font(.subheadline).foregroundStyle(FLColor.text40)

            if isDuration {
                let elapsed = elapsedSeconds(from: exercise.sets[setIndex].started_at)
                let target = exercise.targetDurationSeconds ?? 30
                Text(elapsedFormatted(elapsed))
                    .font(.system(size: 44, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(FLColor.sky)
                Text("目标 \(target) 秒")
                    .font(.subheadline)
                    .foregroundStyle(FLColor.text40)
            } else {
                weightInputRow
            }

            if let tip = exercise.notes.components(separatedBy: CharacterSet(charactersIn: ";；")).first,
               !tip.isEmpty {
                Text("💡 \(tip.trimmingCharacters(in: .whitespaces))")
                    .font(.caption).foregroundStyle(FLColor.amberLight.opacity(0.7))
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                pendingSetIndex = setIndex
                editingSetIndex = nil
                if isDuration {
                    durationInput = max(1, elapsedSeconds(from: exercise.sets[setIndex].started_at))
                }
                inputPhase = .repsInput
            } label: {
                Text(isDuration ? "结束计时并记录 ✓" : "做完了 ✓")
            }
            .buttonStyle(GreenButtonStyle())
        }
        .glassCard(highlight: true)
    }

    private var weightInputRow: some View {
        HStack(spacing: 20) {
            StepperButton(systemName: "minus", size: 56) {
                currentWeight = max(0, currentWeight - 1)
            }
            VStack(spacing: 2) {
                if editingWeight {
                    TextField("", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 36, weight: .bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .focused($manualInputFocused)
                        .onSubmit { commitWeightEdit() }
                        .onChange(of: manualInputFocused) { _, focused in
                            if !focused { commitWeightEdit() }
                        }
                } else {
                    Text(String(format: "%.0f", currentWeight))
                        .font(.system(size: 36, weight: .bold))
                        .monospacedDigit()
                        .onTapGesture {
                            weightText = String(format: "%.0f", currentWeight)
                            editingWeight = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                manualInputFocused = true
                            }
                        }
                }
                Text("kg").font(.title3).foregroundStyle(FLColor.text50)
            }
            .frame(minWidth: 100)
            StepperButton(systemName: "plus", size: 56) {
                currentWeight += 1
            }
        }
    }

    private var repsInputView: some View {
        VStack(spacing: 16) {
            Text("实际完成次数")
                .font(.subheadline).foregroundStyle(FLColor.text40)

            HStack(spacing: 20) {
                StepperButton(systemName: "minus") {
                    repsInput = max(1, repsInput - 1)
                }
                VStack(spacing: 2) {
                    if editingReps {
                        TextField("", text: $repsText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 36, weight: .bold))
                            .monospacedDigit()
                            .multilineTextAlignment(.center)
                            .focused($manualInputFocused)
                            .onSubmit { commitRepsEdit() }
                            .onChange(of: manualInputFocused) { _, focused in
                                if !focused { commitRepsEdit() }
                            }
                    } else {
                        Text("\(repsInput)")
                            .font(.system(size: 36, weight: .bold))
                            .monospacedDigit()
                            .onTapGesture {
                                repsText = "\(repsInput)"
                                editingReps = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    manualInputFocused = true
                                }
                            }
                    }
                    Text("次").font(.subheadline).foregroundStyle(FLColor.text50)
                }
                .frame(minWidth: 80)
                StepperButton(systemName: "plus") {
                    repsInput += 1
                }
            }

            Button("确认") { inputPhase = .rpeSelect }
                .buttonStyle(GreenButtonStyle())
        }
        .glassCard(highlight: true)
    }

    private var durationInputView: some View {
        VStack(spacing: 16) {
            Text("实际完成时长")
                .font(.subheadline).foregroundStyle(FLColor.text40)

            HStack(spacing: 20) {
                StepperButton(systemName: "minus") {
                    durationInput = max(5, durationInput - 5)
                }
                VStack(spacing: 2) {
                    if editingDuration {
                        TextField("", text: $durationText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 36, weight: .bold))
                            .monospacedDigit()
                            .multilineTextAlignment(.center)
                            .focused($manualInputFocused)
                            .onSubmit { commitDurationEdit() }
                            .onChange(of: manualInputFocused) { _, focused in
                                if !focused { commitDurationEdit() }
                            }
                    } else {
                        Text("\(durationInput)")
                            .font(.system(size: 36, weight: .bold))
                            .monospacedDigit()
                            .onTapGesture {
                                durationText = "\(durationInput)"
                                editingDuration = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    manualInputFocused = true
                                }
                            }
                    }
                    Text("秒").font(.subheadline).foregroundStyle(FLColor.text50)
                }
                .frame(minWidth: 80)
                StepperButton(systemName: "plus") {
                    durationInput += 5
                }
            }

            Button("确认") { inputPhase = .rpeSelect }
                .buttonStyle(GreenButtonStyle())
        }
        .glassCard(highlight: true)
    }

    private func pendingSetRow(_ index: Int) -> some View {
        HStack {
            Circle()
                .strokeBorder(FLColor.text20, lineWidth: 1)
                .frame(width: 20, height: 20)
            Text("第 \(index + 1) 组 · 待完成")
                .font(.subheadline).foregroundStyle(FLColor.text30)
            Spacer()
        }
        .glassCard(padding: 16)
        .opacity(0.3)
    }

    // MARK: - Notes

    private func notesCard(_ notes: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("💡").font(.subheadline)
            Text(notes).font(.subheadline).foregroundStyle(FLColor.text60)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 16)
    }

    private var exerciseNotesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("备注").font(.caption).foregroundStyle(FLColor.text40)
            TextField("记录感受...", text: $exerciseNotes, axis: .vertical)
                .lineLimit(2...4)
                .foregroundStyle(.white)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(FLColor.cardBorder))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onChange(of: exerciseNotes) { _, newValue in
                    workoutState.updateExerciseNotes(exerciseId: exerciseId, notes: newValue)
                }
        }
    }

    // MARK: - Bottom Navigation

    private func bottomNavigationDone(_ exercise: LiveExercise) -> some View {
        let nextId = workoutState.getNextExerciseId(after: exerciseId)
        let nextEx = nextId.flatMap { id in workoutState.exercises.first { $0.id == id } }

        return Group {
            if let nextEx {
                Button { navigateToNext() } label: {
                    Text("下一个动作：\(nextEx.name) →")
                }
                .buttonStyle(GreenButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .padding(.bottom, 8)
                .background(FLColor.bg.opacity(0.8).background(.ultraThinMaterial))
            } else {
                Button { dismiss() } label: {
                    Text("← 返回训练总览")
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .padding(.bottom, 8)
                .background(FLColor.bg.opacity(0.8).background(.ultraThinMaterial))
            }
        }
    }

    private func bottomNavigationSkip(_ exercise: LiveExercise) -> some View {
        let nextId = workoutState.getNextExerciseId(after: exerciseId)
        let nextEx = nextId.flatMap { id in workoutState.exercises.first { $0.id == id } }

        return Group {
            if let nextEx {
                Button { navigateToNext() } label: {
                    Text("跳到 \(nextEx.name) →")
                        .font(.subheadline).foregroundStyle(FLColor.text30)
                }
                .padding(.vertical, 8)
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Actions

    private func confirmSet(rpe: Double?) {
        let isDuration = exercise?.type == "duration" || exercise?.type == "core"
        workoutState.completeSet(
            exerciseId: exerciseId, setIndex: pendingSetIndex,
            reps: isDuration ? 0 : repsInput,
            weight: isDuration ? 0 : currentWeight,
            duration: isDuration ? durationInput : nil,
            rpe: rpe
        )
        inputPhase = .idle

        if editingSetIndex != nil {
            editingSetIndex = nil
            return
        }

        guard let exercise else { return }
        let isLastSet = pendingSetIndex == exercise.sets.count - 1
        if !isLastSet {
            let nextTarget = isDuration ? "\(exercise.targetDurationSeconds ?? 30)秒" : "\(formatWeight(exercise.targetWeight))kg × \(exercise.targetReps)"
            restConfig = RestConfig(
                seconds: exercise.restSeconds,
                setInfo: "第 \(pendingSetIndex + 1)/\(exercise.sets.count) 组完成 · 下一组目标：\(nextTarget)"
            )
        } else {
            if let nextId = workoutState.getNextExerciseId(after: exerciseId),
               let nextEx = workoutState.exercises.first(where: { $0.id == nextId }) {
                transitionRestConfig = TransitionRestConfig(
                    seconds: exercise.transitionRestSeconds,
                    nextExercise: nextEx
                )
            }
        }
    }

    private func commitWeightEdit() {
        if let val = Double(weightText), val >= 0 {
            currentWeight = val
        }
        editingWeight = false
    }

    private func commitRepsEdit() {
        if let val = Int(repsText), val >= 1 {
            repsInput = val
        }
        editingReps = false
    }

    private func commitDurationEdit() {
        if let val = Int(durationText), val >= 1 {
            durationInput = val
        }
        editingDuration = false
    }

    private func navigateToNext() {
        guard let nextId = workoutState.getNextExerciseId(after: exerciseId) else { return }
        workoutState.currentExerciseId = nil
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onNavigateToNext?(nextId)
        }
    }

    private func initializeInputs(_ exercise: LiveExercise) {
        workoutState.currentExerciseId = exerciseId
        repsInput = Int(exercise.targetReps.components(separatedBy: "-").last ?? "10") ?? 10
        durationInput = exercise.targetDurationSeconds ?? 30
        currentWeight = exercise.targetWeight
        exerciseNotes = exercise.exerciseNotes
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }

    private func elapsedSeconds(from isoString: String?) -> Int {
        guard let isoString else { return 0 }
        guard let date = DateUtils.iso8601Basic.date(from: isoString) else { return 0 }
        return max(0, Int(now.timeIntervalSince(date)))
    }

    private func elapsedFormatted(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

extension ExerciseDetailView.RestConfig: Identifiable {
    var id: String { "rest-\(seconds)" }
}

extension ExerciseDetailView.TransitionRestConfig: Identifiable {
    var id: String { "transition-\(nextExercise.id)" }
}

