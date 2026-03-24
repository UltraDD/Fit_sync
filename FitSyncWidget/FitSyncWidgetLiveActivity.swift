import ActivityKit
import WidgetKit
import SwiftUI

struct FitSyncWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack {
                        Spacer(minLength: 0)
                        progressRing(context: context, size: 36, lineWidth: 3.5)
                        Spacer(minLength: 0)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack {
                        Spacer(minLength: 0)
                        Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                            .font(.system(.title2, design: .rounded).bold())
                            .monospacedDigit()
                            .foregroundColor(.green)
                        Spacer(minLength: 0)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.mode == "transition" ? "换动作" : "休息中")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.attributes.mode == "transition",
                       let next = context.attributes.nextExerciseName {
                        HStack(spacing: 6) {
                            Text("下一个")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(next)
                                .font(.caption.bold())
                                .foregroundColor(.cyan)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(context.attributes.exerciseName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } compactLeading: {
                progressRing(context: context, size: 18, lineWidth: 2.5)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .font(.system(.caption, design: .rounded).bold())
                    .monospacedDigit()
                    .foregroundColor(.green)
                    .frame(minWidth: 34)
            } minimal: {
                progressRing(context: context, size: 22, lineWidth: 2.5)
            }
            .widgetURL(URL(string: "fitsync://workout"))
            .keylineTint(Color.green)
        }
    }

    // MARK: - Lock Screen Banner

    private func lockScreenView(context: ActivityViewContext<RestTimerAttributes>) -> some View {
        HStack(spacing: 16) {
            progressRing(context: context, size: 44, lineWidth: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.mode == "transition" ? "换动作休息" : "组间休息")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if context.attributes.mode == "transition",
                   let next = context.attributes.nextExerciseName {
                    Text(next)
                        .font(.subheadline.bold())
                        .foregroundColor(.cyan)
                        .lineLimit(1)
                } else {
                    Text(context.attributes.exerciseName)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                .font(.system(.title, design: .rounded).bold())
                .monospacedDigit()
                .foregroundColor(.green)
                .contentTransition(.numericText())
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.85))
        .activitySystemActionForegroundColor(Color.green)
    }

    // MARK: - Progress Ring

    private func progressRing(context: ActivityViewContext<RestTimerAttributes>, size: CGFloat, lineWidth: CGFloat) -> some View {
        let total = max(context.attributes.totalSeconds, 1)
        let remaining = max(context.state.remainingSeconds, 0)
        let progress = Double(remaining) / Double(total)

        return ZStack {
            Circle()
                .stroke(Color.green.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "timer")
                .font(.system(size: size * 0.35))
                .foregroundColor(.green)
        }
        .frame(width: size, height: size)
    }
}
