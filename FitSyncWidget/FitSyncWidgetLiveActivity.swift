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
        ZStack {
            ProgressView(timerInterval: timerRange(context: context), countsDown: true)
                .progressViewStyle(.circular)
                .tint(.green)
                .labelsHidden()

            if showIcon {
                Image(systemName: "timer")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(.green)
            }
        }
        .frame(width: size, height: size)
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
}
