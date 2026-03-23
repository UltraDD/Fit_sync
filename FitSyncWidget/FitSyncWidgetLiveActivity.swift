//
//  FitSyncWidgetLiveActivity.swift
//  FitSyncWidget
//
//  Created by 动动 on 2026/3/23.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FitSyncWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.green)
                    Text(context.attributes.mode == "transition" ? "换动作休息" : "组间休息")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                        .font(.system(.title, design: .monospaced).bold())
                        .foregroundColor(.green)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    if context.attributes.mode == "transition" {
                        Text("✓ \(context.attributes.exerciseName) 完成")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        if let next = context.attributes.nextExerciseName {
                            Text("准备: \(next)")
                                .font(.subheadline.bold())
                                .foregroundColor(.cyan)
                        }
                    } else {
                        Text(context.attributes.exerciseName)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(Color.green)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .foregroundColor(.green)
                        Text(context.attributes.mode == "transition" ? "换动作" : "休息")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                        .font(.system(.title2, design: .monospaced).bold())
                        .foregroundColor(.green)
                        .padding(.top, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if context.attributes.mode == "transition" {
                            if let next = context.attributes.nextExerciseName {
                                Text("下一步: \(next)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.cyan)
                            }
                        } else {
                            Text(context.attributes.exerciseName)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(.green)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundColor(.green)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(.green)
            }
            .widgetURL(URL(string: "fitsync://workout"))
            .keylineTint(Color.green)
        }
    }
}
