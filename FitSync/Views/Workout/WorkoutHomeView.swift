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

                        if !workoutState.active, !homeVM.planCompleted,
                           let plan = homeVM.plan,
                           let notes = plan.coach_notes, !notes.isEmpty {
                            coachNotesCard(notes)
                        }

                        if !workoutState.active, let last = WorkoutStore.shared.lastWorkout() {
                            if !(homeVM.planCompleted && homeVM.plan?.date == last.date) {
                                lastWorkoutCard(last)
                            }
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
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }

            Spacer()

            Text("FITLOG")
                .font(.title3.bold())
                .tracking(6)
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

    private var todayResult: ResultJSON? {
        guard let plan = homeVM.plan, homeVM.planCompleted else { return nil }
        return WorkoutStore.shared.history.first {
            $0.date == plan.date || $0.plan_ref == plan.date
        }
    }

    private var planCard: some View {
        Group {
            if let plan = homeVM.plan {
                if homeVM.planCompleted {
                    completedPlanCard(plan)
                } else {
                    pendingPlanCard(plan)
                }
            } else if homeVM.syncing {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("正在同步计划...").font(.subheadline).foregroundStyle(FLColor.text40)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                noPlanCard
            }
        }
    }

    private func completedPlanCard(_ plan: PlanJSON) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(FLColor.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日训练已完成")
                        .font(.headline)
                    Text(plan.target_muscles.joined(separator: " + "))
                        .font(.subheadline)
                        .foregroundStyle(FLColor.text50)
                }
                Spacer()
            }

            if let result = todayResult {
                let sets = result.exercises.reduce(0) { $0 + ($1.sets?.count ?? 0) }
                let mw = result.exercises.flatMap { $0.sets ?? [] }.map(\.weight_kg).max() ?? 0

                HStack(spacing: 0) {
                    completedStat("\(result.duration_minutes)", label: "分钟")
                    completedStat("\(result.exercises.count)", label: "动作")
                    completedStat("\(sets)", label: "组")
                    if mw > 0 {
                        completedStat(String(format: "%.0f", mw), label: "kg")
                    }
                }

                HStack {
                    HStack(spacing: 4) {
                        Text("体感").font(.caption).foregroundStyle(FLColor.text40)
                        Text("\(result.overall_feeling)/10")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    Spacer()
                    if !result.start_time.isEmpty && !result.end_time.isEmpty {
                        Text("\(result.start_time) – \(result.end_time)")
                            .font(.caption).foregroundStyle(FLColor.text30)
                    }
                }
            }
        }
        .glassCard()
    }

    private func completedStat(_ value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(FLColor.text40)
        }
        .frame(maxWidth: .infinity)
    }

    private func pendingPlanCard(_ plan: PlanJSON) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                FLBadge(text: "发现新计划", color: FLColor.green)
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
                Text("开始训练")
            }
            .buttonStyle(GreenButtonStyle())
        }
        .glassCard(highlight: true)
    }

    private var noPlanCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 36))
                .foregroundStyle(FLColor.text20)

            Text("暂无训练计划")
                .font(.headline)
                .foregroundStyle(FLColor.text50)

            if homeVM.isConfigured {
                if let sync = homeVM.lastSync {
                    Text("上次同步 \(sync)")
                        .font(.caption)
                        .foregroundStyle(FLColor.text30)
                }
                Button("刷新") { Task { await homeVM.fetchPlan() } }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: false))
            } else {
                Text("配置 GitHub 后可自动同步 AI 生成的计划")
                    .font(.subheadline)
                    .foregroundStyle(FLColor.text30)
                    .multilineTextAlignment(.center)

                NavigationLink {
                    SettingsView()
                } label: {
                    Label("前往设置", systemImage: "gearshape")
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: false))
            }

            Button {
                workoutState.startWorkout(plan: nil)
                navigateToSession = true
            } label: {
                Text("直接开始自由训练 →")
            }
            .buttonStyle(GreenButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
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
