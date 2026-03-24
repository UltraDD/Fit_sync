import SwiftUI

struct RestTimerView: View {
    let seconds: Int
    let exerciseName: String
    let setInfo: String
    let mode: RestMode
    var nextExercise: LiveExercise?
    var onDone: () -> Void

    enum RestMode { case setRest, transition }

    @State private var remaining: Int
    @State private var total: Int
    @State private var timer: Timer?
    @State private var endTime: Date
    @State private var hasFired = false

    private var accent: Color { mode == .transition ? FLColor.sky : FLColor.green }

    init(seconds: Int, exerciseName: String, setInfo: String, mode: RestMode = .setRest, nextExercise: LiveExercise? = nil, onDone: @escaping () -> Void) {
        self.seconds = seconds
        self.exerciseName = exerciseName
        self.setInfo = setInfo
        self.mode = mode
        self.nextExercise = nextExercise
        self.onDone = onDone
        self._remaining = State(initialValue: seconds)
        self._total = State(initialValue: seconds)
        self._endTime = State(initialValue: Date().addingTimeInterval(TimeInterval(seconds)))
    }

    var body: some View {
        ZStack {
            FLColor.bg.opacity(0.95)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            Circle()
                .fill(accent.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 100)

            VStack(spacing: 32) {
                Spacer()

                Text(mode == .transition ? "换动作休息" : "组间休息")
                    .font(.subheadline)
                    .foregroundStyle(FLColor.text40)
                    .textCase(.uppercase)
                    .tracking(4)

                if remaining == 0 {
                    Text("GO")
                        .font(.system(size: 96, weight: .bold))
                        .foregroundStyle(FLColor.green)
                } else {
                    Text(timeString)
                        .font(.system(size: 96, weight: .bold))
                        .monospacedDigit()
                        .tracking(-2)
                        .contentTransition(.numericText())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accent.opacity(0.6))
                            .frame(width: geo.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 40)

                VStack(spacing: 6) {
                    if mode == .transition {
                        Label("✓ \(exerciseName) 全部完成", systemImage: "checkmark.circle.fill")
                            .font(.subheadline).foregroundStyle(FLColor.text40)
                    } else {
                        Text(exerciseName).font(.headline)
                        if !setInfo.isEmpty {
                            Text(setInfo)
                                .font(.subheadline).foregroundStyle(FLColor.text40)
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                if let next = nextExercise {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.forward.circle.fill")
                                .foregroundStyle(FLColor.sky)
                            Text("下一步准备 (Up Next)")
                                .font(.subheadline.bold())
                                .foregroundStyle(FLColor.sky)
                        }
                        
                        Text(next.name)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 16) {
                            if next.type == "strength" {
                                nextInfoItem(title: "目标重量", value: "\(formatWeight(next.targetWeight))kg")
                                nextInfoItem(title: "目标组数", value: "\(next.targetSets)组")
                                nextInfoItem(title: "目标次数", value: "\(next.targetReps)次")
                            } else if next.type == "duration" || next.type == "core" {
                                nextInfoItem(title: "目标组数", value: "\(next.targetSets)组")
                                nextInfoItem(title: "目标时长", value: "\(next.targetDurationSeconds ?? 30)秒")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button { add30Seconds() } label: {
                        Text("+30秒")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        cleanup()
                        onDone()
                    } label: {
                        Text("跳过")
                    }
                    .buttonStyle(GreenButtonStyle())
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 40)
            }
        }
        .onAppear { startTimer() }
        .onDisappear { cleanup() }
        .onChange(of: remaining) { _, newValue in
            if newValue <= 0 && !hasFired {
                hasFired = true
                fireHaptic()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    cleanup()
                    onDone()
                }
            }
        }
    }

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return min(1, CGFloat(total - remaining) / CGFloat(total))
    }

    private var timeString: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }

    private func nextInfoItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(FLColor.text40)
            Text(value).font(.subheadline.bold()).foregroundStyle(.white)
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            recalculate()
        }
        LiveActivityManager.shared.startTimer(
            exerciseName: exerciseName,
            nextExerciseName: nextExercise?.name,
            mode: mode == .transition ? "transition" : "setRest",
            seconds: remaining
        )
    }

    private func recalculate() {
        let left = max(0, Int(ceil(endTime.timeIntervalSinceNow)))
        remaining = left
        if left > 0 && left % 5 == 0 {
            LiveActivityManager.shared.updateTimer(seconds: left)
        }
    }

    private func add30Seconds() {
        endTime = endTime.addingTimeInterval(30)
        total += 30
        hasFired = false
        recalculate()
        if timer == nil { startTimer() }
        LiveActivityManager.shared.updateTimer(seconds: remaining)
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        LiveActivityManager.shared.stopTimer()
    }

    private func fireHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            generator.notificationOccurred(.success)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            generator.notificationOccurred(.success)
        }
    }
}
