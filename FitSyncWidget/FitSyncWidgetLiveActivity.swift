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
                    progressRing(context: context, size: 30, showIcon: true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(context: context, font: .system(.headline, design: .rounded).bold(), width: 52)
                }
                DynamicIslandExpandedRegion(.center) {
                    expandedSummary(context: context)
                }
            } compactLeading: {
                progressRing(context: context, size: 18)
            } compactTrailing: {
                timerText(context: context, font: .system(.caption2, design: .rounded).bold(), width: 42)
            } minimal: {
                progressRing(context: context, size: 22)
            }
            .widgetURL(URL(string: "fitsync://workout"))
            .keylineTint(Color.green)
        }
    }

    // MARK: - Lock Screen Banner

    private func lockScreenView(context: ActivityViewContext<RestTimerAttributes>) -> some View {
        HStack(spacing: 16) {
            progressRing(context: context, size: 44, showIcon: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.mode == "transition" ? "换动作休息" : "组间休息")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if context.attributes.mode == "transition",
                   let next = context.attributes.nextExerciseName {
                    Text(next)
                        .font(.subheadline.bold())
                        .foregroundStyle(.cyan)
                        .lineLimit(1)
                } else {
                    Text(context.attributes.exerciseName)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }

            Spacer()

            timerText(context: context, font: .system(.title, design: .rounded).bold(), width: 70)
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.85))
        .activitySystemActionForegroundColor(Color.green)
    }

    // MARK: - Progress Ring

    private func expandedSummary(context: ActivityViewContext<RestTimerAttributes>) -> some View {
        VStack(spacing: 1) {
            Text(context.attributes.mode == "transition" ? "换动作" : "休息中")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(summaryTitle(context: context))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(context.attributes.mode == "transition" ? .cyan : .white)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: 96)
    }

    private func timerText(context: ActivityViewContext<RestTimerAttributes>, font: Font, width: CGFloat) -> some View {
        Text(timerInterval: timerRange(context: context), countsDown: true)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(.green)
            .contentTransition(.numericText())
            .frame(width: width, alignment: .trailing)
    }

    private func progressRing(context: ActivityViewContext<RestTimerAttributes>, size: CGFloat, showIcon: Bool = false) -> some View {
        TimelineView(.periodic(from: context.state.startTime, by: 1)) { timeline in
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.18), lineWidth: ringLineWidth(for: size))

                Circle()
                    .trim(from: 0, to: remainingProgress(context: context, now: timeline.date))
                    .stroke(
                        Color.green,
                        style: StrokeStyle(lineWidth: ringLineWidth(for: size), lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                if showIcon {
                    Image(systemName: "timer")
                        .font(.system(size: size * 0.3))
                        .foregroundStyle(.green)
                }
            }
            .frame(width: size, height: size)
        }
    }

    private func timerRange(context: ActivityViewContext<RestTimerAttributes>) -> ClosedRange<Date> {
        min(context.state.startTime, context.state.endTime)...max(context.state.startTime, context.state.endTime)
    }

    private func summaryTitle(context: ActivityViewContext<RestTimerAttributes>) -> String {
        if context.attributes.mode == "transition",
           let next = context.attributes.nextExerciseName,
           !next.isEmpty {
            return next
        }
        return context.attributes.exerciseName
    }

    private func remainingProgress(context: ActivityViewContext<RestTimerAttributes>, now: Date) -> Double {
        let total = max(context.state.endTime.timeIntervalSince(context.state.startTime), 1)
        let remaining = max(context.state.endTime.timeIntervalSince(now), 0)
        return min(max(remaining / total, 0), 1)
    }

    private func ringLineWidth(for size: CGFloat) -> CGFloat {
        max(2, size * 0.11)
    }
}
