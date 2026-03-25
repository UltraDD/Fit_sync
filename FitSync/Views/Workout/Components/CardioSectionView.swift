import SwiftUI

struct CardioSectionView: View {
    @Bindable var workoutState: WorkoutState
    let exerciseId: String
    let exercise: LiveExercise
    let now: Date

    @State private var cardioIncline: Double = 0
    @State private var cardioSpeed: Double = 6
    @State private var cardioDuration: Double = 20
    @State private var cardioDistance: Double = 0
    @State private var cardioSaved = false
    @State private var cardioPhase: CardioPhase = .timing

    @State private var editingCardioField: String?
    @State private var cardioFieldText = ""
    @FocusState private var fieldFocused: Bool

    enum CardioPhase { case timing, editing }

    var body: some View {
        if cardioPhase == .timing {
            cardioTimerView
        } else {
            cardioRecorderView
        }
    }

    // MARK: - Timer

    private var cardioTimerView: some View {
        let elapsed = elapsedSeconds(from: exercise.startedAt)
        let targetMinutes = exercise.targetCardio?.duration_minutes
        let targetSeconds = targetMinutes.map { $0 * 60 }
        let progress: Double? = targetSeconds.map { t in min(1.0, Double(elapsed) / Double(t)) }
        let reachedTarget = targetSeconds.map { elapsed >= $0 } ?? false

        return VStack(spacing: 16) {
            Text("有氧进行中")
                .font(.subheadline).foregroundStyle(FLColor.text40)

            ZStack {
                if let progress {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 8)
                        .frame(width: 180, height: 180)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(reachedTarget ? FLColor.green : FLColor.sky, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)
                }

                VStack(spacing: 4) {
                    Text(elapsedFormatted(elapsed))
                        .font(.system(size: 44, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(reachedTarget ? FLColor.green : .white)
                    if let target = targetMinutes {
                        Text("/ \(target):00")
                            .font(.title3)
                            .monospacedDigit()
                            .foregroundStyle(FLColor.text40)
                    }
                }
            }

            if let tc = exercise.targetCardio {
                HStack(spacing: 16) {
                    if let incline = tc.incline_pct {
                        paramChip("坡度", value: String(format: "%.0f%%", incline))
                    }
                    if let speed = tc.speed_kmh {
                        paramChip("速度", value: String(format: "%.1f km/h", speed))
                    }
                    if let hr = tc.target_hr_range, hr.count == 2 {
                        paramChip("心率", value: "\(hr[0])-\(hr[1])")
                    }
                }
            }

            Button {
                cardioDuration = max(1, Double(elapsed) / 60.0)
                cardioPhase = .editing
            } label: {
                Text("结束计时并填写参数")
            }
            .buttonStyle(GreenButtonStyle())
        }
        .glassCard(highlight: true)
    }

    // MARK: - Recorder

    private var cardioRecorderView: some View {
        VStack(spacing: 20) {
            stepperRow("坡度", value: $cardioIncline, step: 0.5, unit: "%", format: "%.1f")
            stepperRow("速度", value: $cardioSpeed, step: 0.5, unit: "km/h", format: "%.1f")
            stepperRow("时长", value: $cardioDuration, step: 1, unit: "分钟", format: "%.0f")
            stepperRow("距离（选填）", value: $cardioDistance, step: 0.1, unit: "km", format: "%.1f")

            Button {
                workoutState.updateCardio(exerciseId: exerciseId, data: CardioData(
                    incline_pct: cardioIncline > 0 ? cardioIncline : nil,
                    speed_kmh: cardioSpeed > 0 ? cardioSpeed : nil,
                    duration_minutes: cardioDuration,
                    distance_km: cardioDistance > 0 ? cardioDistance : nil
                ))
                cardioSaved = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { cardioSaved = false }
            } label: {
                Text(cardioSaved ? "已保存 ✓" : "保存记录")
            }
            .buttonStyle(GreenButtonStyle())

            Button("继续计时") { cardioPhase = .timing }
                .font(.subheadline)
                .foregroundStyle(FLColor.text40)
        }
        .glassCard()
    }

    // MARK: - Stepper Row

    private func stepperRow(_ label: String, value: Binding<Double>, step: Double, unit: String, format: String) -> some View {
        let fieldId = label
        let isEditing = editingCardioField == fieldId

        return HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(FLColor.text50)
                .frame(width: 90, alignment: .leading)

            StepperButton(systemName: "minus", size: 40) {
                value.wrappedValue = max(0, value.wrappedValue - step)
            }

            VStack(spacing: 1) {
                if isEditing {
                    TextField("", text: $cardioFieldText)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .focused($fieldFocused)
                        .onSubmit {
                            if let val = Double(cardioFieldText), val >= 0 { value.wrappedValue = val }
                            editingCardioField = nil
                        }
                        .onChange(of: fieldFocused) { _, focused in
                            if !focused {
                                if let val = Double(cardioFieldText), val >= 0 { value.wrappedValue = val }
                                editingCardioField = nil
                            }
                        }
                } else {
                    Text(String(format: format, value.wrappedValue))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .onTapGesture {
                            cardioFieldText = String(format: format, value.wrappedValue)
                            editingCardioField = fieldId
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                fieldFocused = true
                            }
                        }
                }
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(FLColor.text40)
            }
            .frame(minWidth: 70)

            StepperButton(systemName: "plus", size: 40) {
                value.wrappedValue += step
            }
        }
    }

    // MARK: - Helpers

    private func paramChip(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(FLColor.text30)
            Text(value).font(.caption.bold()).foregroundStyle(FLColor.text60)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

    func initializeFrom(_ exercise: LiveExercise) {
        if let cardio = exercise.cardioData {
            cardioIncline = cardio.incline_pct ?? 0
            cardioSpeed = cardio.speed_kmh ?? 6
            cardioDuration = cardio.duration_minutes
            cardioDistance = cardio.distance_km ?? 0
        }
        cardioPhase = (exercise.cardioData?.duration_minutes ?? 0) > 0 ? .editing : .timing
    }
}
