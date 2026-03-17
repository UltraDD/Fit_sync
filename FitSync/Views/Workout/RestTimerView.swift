import SwiftUI

struct RestTimerView: View {
    let seconds: Int
    let exerciseName: String
    let setInfo: String
    let nextInfo: String

    @State private var remaining: Int
    @State private var timer: Timer?
    @Environment(\.dismiss) private var dismiss

    init(seconds: Int, exerciseName: String, setInfo: String, nextInfo: String) {
        self.seconds = seconds
        self.exerciseName = exerciseName
        self.setInfo = setInfo
        self.nextInfo = nextInfo
        self._remaining = State(initialValue: seconds)
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("组间休息")
                .font(.title3).foregroundStyle(.secondary)

            Text(timeString)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()

            ProgressView(value: Double(seconds - remaining), total: Double(seconds))
                .tint(.blue)
                .padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text("\(exerciseName) · \(setInfo)")
                    .font(.subheadline)
                Text(nextInfo)
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 32) {
                Button("+30秒") { remaining += 30 }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Button("跳过") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }

            Spacer()
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    private var timeString: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%d:%02d", m, s)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remaining > 0 {
                remaining -= 1
            } else {
                timer?.invalidate()
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    generator.notificationOccurred(.success)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    generator.notificationOccurred(.success)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            }
        }
    }
}
