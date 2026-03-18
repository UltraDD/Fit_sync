import SwiftUI

struct WorkoutHomeView: View {
    @Bindable var workoutState: WorkoutState
    var homeVM: HomeViewModel
    @State private var showImportSheet = false
    @State private var importText = ""
    @State private var importError = ""
    @State private var navigateToSession = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        headerView

                        if workoutState.active {
                            resumeLiveBanner
                        }

                        if !workoutState.active, let draftInfo = workoutState.draftInfo {
                            resumeDraftBanner(draftInfo)
                        }

                        if !workoutState.active {
                            planCard
                        }

                        if !workoutState.active, let plan = homeVM.plan,
                           let notes = plan.coach_notes, !notes.isEmpty {
                            coachNotesCard(notes)
                        }

                        if !workoutState.active, let last = WorkoutStore.shared.lastWorkout() {
                            lastWorkoutCard(last)
                        }

                        quickActions

                        NavigationLink {
                            WorkoutHistoryView()
                        } label: {
                            Text("全部历史记录 →")
                                .font(.subheadline)
                                .foregroundStyle(FLColor.text40)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .refreshable { await homeVM.fetchPlan() }
            }
            .navigationDestination(isPresented: $navigateToSession) {
                WorkoutSessionView(workoutState: workoutState, homeVM: homeVM)
            }
            .sheet(isPresented: $showImportSheet) {
                importSheet
            }
            .task { await homeVM.fetchPlan() }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(FLColor.text50)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(FLColor.cardBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Spacer()

            Text("F I T L O G")
                .font(.title3.bold())
                .tracking(2)
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                if let sync = homeVM.lastSync {
                    Text(sync)
                        .font(.caption2)
                        .foregroundStyle(FLColor.text40)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var statusColor: Color {
        switch homeVM.connectionStatus {
        case .connected: FLColor.green
        case .noConfig: FLColor.text30
        case .invalidToken: FLColor.red
        case .offline: FLColor.yellow
        }
    }

    // MARK: - Resume Live

    private var resumeLiveBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(FLColor.green).frame(width: 8, height: 8)
                Text("训练进行中")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(FLColor.green)
            }

            Text("\(workoutState.plan?.target_muscles.joined(separator: " + ") ?? "自由训练") · \(workoutState.exercises.count) 个动作 · \(workoutState.elapsedFormatted)")
                .font(.subheadline).foregroundStyle(FLColor.text50)

            HStack(spacing: 12) {
                Button("继续训练") {
                    navigateToSession = true
                }
                .buttonStyle(GreenButtonStyle(fullWidth: false))
                .frame(maxWidth: .infinity)

                Button("放弃") {
                    workoutState.reset()
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                .frame(maxWidth: .infinity)
            }
        }
        .glassCard(highlight: true)
    }

    // MARK: - Resume Draft

    private func resumeDraftBanner(_ info: (muscles: String, exerciseCount: Int, elapsed: Int)) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            FLBadge(text: "未完成的训练", color: FLColor.amber)

            Text("\(info.muscles) · \(info.exerciseCount) 个动作 · 已用时 \(formatElapsed(info.elapsed))")
                .font(.subheadline).foregroundStyle(FLColor.text50)

            HStack(spacing: 12) {
                Button("恢复训练") {
                    workoutState.loadDraft()
                    navigateToSession = true
                }
                .buttonStyle(GreenButtonStyle(fullWidth: false))
                .frame(maxWidth: .infinity)

                Button("放弃") {
                    workoutState.clearDraft()
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                .frame(maxWidth: .infinity)
            }
        }
        .glassCard()
    }

    // MARK: - Plan Card

    private var planCard: some View {
        Group {
            if homeVM.syncing {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("正在同步计划...").font(.subheadline).foregroundStyle(FLColor.text40)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if let plan = homeVM.plan {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        if homeVM.planCompleted {
                            FLBadge(text: "今日计划已完成", color: FLColor.text50)
                        } else {
                            FLBadge(text: "发现新计划", color: FLColor.green)
                        }
                        Spacer()
                        Text(plan.date).font(.subheadline).foregroundStyle(FLColor.text40)
                    }

                    Text(plan.target_muscles.joined(separator: " + "))
                        .font(.title3.bold())

                    Text("\(plan.exercises.count) 个动作 · 预计 \(plan.estimated_minutes) 分钟")
                        .font(.subheadline).foregroundStyle(FLColor.text50)

                    if let greeting = plan.coach_greeting, !greeting.isEmpty {
                        Text(greeting)
                            .font(.subheadline)
                            .foregroundStyle(FLColor.amberLight.opacity(0.8))
                    }

                    Button {
                        workoutState.startWorkout(plan: plan)
                        navigateToSession = true
                    } label: {
                        Text(homeVM.planCompleted ? "再练一次" : "开始训练")
                    }
                    .buttonStyle(GreenButtonStyle())
                }
                .glassCard(highlight: !homeVM.planCompleted)
            } else {
                VStack(spacing: 10) {
                    Text("暂无新计划")
                        .font(.subheadline)
                        .foregroundStyle(FLColor.text40)
                    if let sync = homeVM.lastSync {
                        Text("上次同步 \(sync)")
                            .font(.caption)
                            .foregroundStyle(FLColor.text30)
                    }
                    Button("刷新") { Task { await homeVM.fetchPlan() } }
                        .buttonStyle(SecondaryButtonStyle(fullWidth: false))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
    }

    // MARK: - Coach Notes

    private func coachNotesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🗣️ 教练备注")
                .font(.caption).foregroundStyle(FLColor.amberLight.opacity(0.6))
            Text(notes)
                .font(.subheadline).foregroundStyle(FLColor.text60)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 16)
    }

    // MARK: - Last Workout

    private func lastWorkoutCard(_ w: ResultJSON) -> some View {
        NavigationLink {
            WorkoutHistoryView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("上次训练")
                    .font(.caption2.weight(.medium))
                    .tracking(1)
                    .foregroundStyle(FLColor.text30)
                    .textCase(.uppercase)

                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(w.date).font(.subheadline.bold())
                        HStack(spacing: 12) {
                            Label("\(w.exercises.count) 动作", systemImage: "figure.strengthtraining.traditional")
                            Label("\(w.duration_minutes) 分钟", systemImage: "clock")
                        }
                        .font(.caption).foregroundStyle(FLColor.text40)
                    }
                    Spacer()
                    Text("\(w.overall_feeling)")
                        .font(.title3.bold())
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                workoutState.startWorkout(plan: nil)
                navigateToSession = true
            } label: {
                Label("自由训练", systemImage: "figure.strengthtraining.traditional")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button { showImportSheet = true } label: {
                Label("导入计划", systemImage: "doc.badge.plus")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: - Import Sheet

    private var importSheet: some View {
        NavigationStack {
            ZStack {
                FLColor.bg.ignoresSafeArea()

                VStack(spacing: 16) {
                    TextEditor(text: $importText)
                        .scrollContentBackground(.hidden)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(minHeight: 200)
                        .padding(12)
                        .background(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(FLColor.cardBorder))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    if !importError.isEmpty {
                        Text(importError).foregroundStyle(FLColor.red).font(.caption)
                    }

                    Button("导入") {
                        do {
                            let plan = try homeVM.importPlan(json: importText)
                            showImportSheet = false
                            importText = ""
                            importError = ""
                            workoutState.startWorkout(plan: plan)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                navigateToSession = true
                            }
                        } catch {
                            importError = error.localizedDescription
                        }
                    }
                    .buttonStyle(GreenButtonStyle())
                    .disabled(importText.isEmpty)
                    .opacity(importText.isEmpty ? 0.4 : 1)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("导入训练计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showImportSheet = false
                        importError = ""
                    }
                    .foregroundStyle(FLColor.text60)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatElapsed(_ s: Int) -> String {
        let m = s / 60
        return m > 0 ? "\(m)分钟" : "\(s)秒"
    }
}
