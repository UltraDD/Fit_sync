import SwiftUI

struct WorkoutHomeView: View {
    @Bindable var workoutState: WorkoutState
    var homeVM: HomeViewModel
    @State private var showImportSheet = false
    @State private var importText = ""
    @State private var importError = ""
    @State private var navigateToSession = false
    @State private var navigateToFinish = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerView

                    if workoutState.active {
                        resumeBanner
                    }

                    if let greeting = homeVM.plan?.coach_greeting, !workoutState.active {
                        coachGreetingCard(greeting)
                    }

                    if !workoutState.active {
                        planCard
                    }

                    quickActions

                    NavigationLink("全部历史记录 →", destination: WorkoutHistoryView())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .refreshable { await homeVM.fetchPlan() }
            .navigationDestination(isPresented: $navigateToSession) {
                WorkoutSessionView(workoutState: workoutState, homeVM: homeVM)
            }
            .navigationDestination(isPresented: $navigateToFinish) {
                WorkoutFinishView(workoutState: workoutState, homeVM: homeVM)
            }
            .sheet(isPresented: $showImportSheet) {
                importSheet
            }
            .task { await homeVM.fetchPlan() }
        }
    }

    private var headerView: some View {
        HStack {
            Text("FitSync")
                .font(.title.bold())
                .tracking(2)
            Spacer()
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        }
    }

    private var statusColor: Color {
        switch homeVM.connectionStatus {
        case .connected: .green
        case .noConfig: .yellow
        case .invalidToken: .red
        case .offline: .orange
        }
    }

    private var resumeBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("训练进行中").font(.subheadline.bold()).foregroundStyle(.green)
            }
            Text("\(workoutState.plan?.target_muscles.joined(separator: " + ") ?? "自由训练") · \(workoutState.exercises.count) 个动作 · \(workoutState.elapsedFormatted)")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("继续训练") { navigateToSession = true }
                    .buttonStyle(.borderedProminent)
                Button("放弃") {
                    workoutState.reset()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func coachGreetingCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("教练寄语", systemImage: "quote.opening")
                .font(.caption).foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var planCard: some View {
        Group {
            if homeVM.syncing {
                ProgressView("正在拉取计划...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if let plan = homeVM.plan {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(plan.date).font(.headline)
                        Spacer()
                        Text(plan.target_muscles.joined(separator: " + "))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("\(plan.exercises.count) 个动作 · 预计 \(plan.estimated_minutes) 分钟")
                        .font(.subheadline).foregroundStyle(.secondary)

                    Button {
                        workoutState.startWorkout(plan: plan)
                        navigateToSession = true
                    } label: {
                        Text("开始训练")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 12) {
                    Text("暂无训练计划").foregroundStyle(.secondary)
                    Button("刷新") { Task { await homeVM.fetchPlan() } }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                workoutState.startWorkout(plan: nil)
                navigateToSession = true
            } label: {
                Label("自由训练", systemImage: "figure.strengthtraining.traditional")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button { showImportSheet = true } label: {
                Label("导入计划", systemImage: "doc.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var importSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextEditor(text: $importText)
                    .frame(minHeight: 200)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))

                if !importError.isEmpty {
                    Text(importError).foregroundStyle(.red).font(.caption)
                }

                Button("导入") {
                    do {
                        let plan = try homeVM.importPlan(json: importText)
                        showImportSheet = false
                        importText = ""
                        importError = ""
                        workoutState.startWorkout(plan: plan)
                        navigateToSession = true
                    } catch {
                        importError = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(importText.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("导入训练计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showImportSheet = false
                        importError = ""
                    }
                }
            }
        }
    }
}
