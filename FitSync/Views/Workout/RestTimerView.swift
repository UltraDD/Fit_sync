import SwiftUI

struct RestTimerView: View {
    let seconds: Int
    let exerciseName: String
    let setInfo: String
    let mode: RestMode
    var nextExerciseName: String?
    var onDone: () -> Void

    enum RestMode { case setRest, transition }

    @State private var remaining: Int
    @State private var total: Int
    @State private var timer: Timer?
    @State private var endTime: Date
    @State private var hasFired = false

    private var accent: Color { mode == .transition ? FLColor.sky : FLColor.green }

    init(seconds: Int, exerciseName: String, setInfo: String, mode: RestMode = .setRest, nextExerciseName: String? = nil, onDone: @escaping () -> Void) {
        self.seconds = seconds
        self.exerciseName = exerciseName
        self.setInfo = setInfo
        self.mode = mode
        self.nextExerciseName = nextExerciseName
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
                        if let next = nextExerciseName {
                            Text("准备：\(next)")
                                .font(.title3.bold())
                                .foregroundStyle(FLColor.sky.opacity(0.8))
                        }
                    } else {
                        Text(exerciseName).font(.headline)
                        if !setInfo.isEmpty {
                            Text(setInfo)
                                .font(.subheadline).foregroundStyle(FLColor.text40)
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                Spacer()

                GlassEffectContainer(spacing: 20) {
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

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            recalculate()
        }
    }

    private func recalculate() {
        let left = max(0, Int(ceil(endTime.timeIntervalSinceNow)))
        remaining = left
    }

    private func add30Seconds() {
        endTime = endTime.addingTimeInterval(30)
        total += 30
        hasFired = false
        recalculate()
        if timer == nil { startTimer() }
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
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
