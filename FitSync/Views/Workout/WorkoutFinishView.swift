import SwiftUI

struct WorkoutFinishView: View {
    @Bindable var workoutState: WorkoutState
    var homeVM: HomeViewModel
    @State private var journal: String = ""
    @State private var isSaving = false
    @State private var localStep: StepState = .idle
    @State private var githubStep: StepState = .idle
    @State private var restored = false
    @Environment(\.dismiss) private var dismiss

    enum StepState: Equatable { case idle, running, done, failed(String) }

    private var totalSets: Int {
        workoutState.exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
    }
    private var maxWeight: Double { workoutState.maxWeight }
    private var durationMin: Int { workoutState.elapsedSeconds / 60 }
    private var allDone: Bool {
        localStep == .done && (githubStep == .done || !homeVM.isConfigured)
    }
    private var hasFailed: Bool {
        if case .failed = githubStep { return true }
        return false
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 20) {
                    Text("训练完成!")
                        .font(.largeTitle.bold())
                        .padding(.top, 16)

                    summarySection
                    journalSection

                    if !isSaving && localStep == .idle {
                        saveButton
                    } else if isSaving || localStep != .idle {
                        saveProgressSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("训练总结")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if workoutState.exercises.isEmpty && !restored {
                restored = true
                _ = workoutState.restoreFromSnapshot()
            }
            journal = workoutState.journalText
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        HStack(spacing: 0) {
            statItem("\(durationMin)", label: "分钟")
            statItem("\(workoutState.exercises.count)", label: "动作")
            statItem("\(totalSets)", label: "组")
            if maxWeight > 0 {
                statItem(String(format: "%.0f", maxWeight), label: "kg 最大")
            }
        }
        .glassCard(padding: 24)
    }

    private func statItem(_ value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .default))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(FLColor.text40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Journal

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("训练随笔").font(.subheadline).foregroundStyle(FLColor.text50)
            TextField("今天的训练感受、身体状态...", text: $journal, axis: .vertical)
                .lineLimit(3...8)
                .foregroundStyle(.white)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(FLColor.cardBorder))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .glassCard()
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task { await handleSaveAndSync() }
        } label: {
            Text("保存并同步")
        }
        .buttonStyle(GreenButtonStyle())
        .disabled(workoutState.exercises.isEmpty)
        .opacity(workoutState.exercises.isEmpty ? 0.4 : 1)
    }

    // MARK: - Save Progress

    private var saveProgressSection: some View {
        VStack(spacing: 16) {
            stepRow(
                icon: stepIcon(localStep),
                color: stepColor(localStep),
                label: "保存到本地",
                spinning: localStep == .running
            )

            if homeVM.isConfigured {
                stepRow(
                    icon: stepIcon(githubStep),
                    color: stepColor(githubStep),
                    label: "同步到 GitHub",
                    spinning: githubStep == .running
                )
            }

            if case .failed(let msg) = githubStep {
                Text(msg).font(.caption).foregroundStyle(FLColor.red)
                Button("重试同步") {
                    Task { await retrySyncOnly() }
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: false))
            }

            if allDone || hasFailed {
                Button("返回首页") { handleDone() }
                    .buttonStyle(SecondaryButtonStyle())

                Button("复制到剪贴板") {
                    let result = workoutState.buildResult(feeling: 0, journal: journal, sleepHours: 0)
                    if let data = try? JSONEncoder().encode(result),
                       let str = String(data: data, encoding: .utf8) {
                        UIPasteboard.general.string = str
                    }
                }
                .font(.subheadline).foregroundStyle(FLColor.text40)
            }
        }
        .glassCard()
    }

    private func stepRow(icon: String, color: Color, label: String, spinning: Bool) -> some View {
        HStack(spacing: 12) {
            if spinning {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(color)
                    .frame(width: 20, height: 20)
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(spinning ? FLColor.text50 : .white)
            Spacer()
        }
    }

    private func stepIcon(_ state: StepState) -> String {
        switch state {
        case .idle: "circle"
        case .running: ""
        case .done: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }

    private func stepColor(_ state: StepState) -> Color {
        switch state {
        case .idle: FLColor.text30
        case .running: FLColor.text50
        case .done: FLColor.green
        case .failed: FLColor.red
        }
    }

    // MARK: - Actions

    private func handleSaveAndSync() async {
        isSaving = true
        localStep = .running
        if homeVM.isConfigured { githubStep = .idle }

        let result = workoutState.buildResult(feeling: 0, journal: journal, sleepHours: 0)

        WorkoutStore.shared.save(result)
        workoutState.clearDraft()
        localStep = .done

        guard homeVM.isConfigured else { isSaving = false; return }

        githubStep = .running
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let jsonData = try? encoder.encode(result) else {
            githubStep = .failed("编码失败")
            isSaving = false
            return
        }
        do {
            _ = try await homeVM.githubService.pushFileWithDedup(
                owner: homeVM.githubOwner, repo: homeVM.githubRepo,
                token: homeVM.githubToken, directory: homeVM.inboxPath,
                baseName: result.date, content: jsonData,
                commitMessage: "[FitSync] workout \(result.date)")
            githubStep = .done
        } catch {
            githubStep = .failed(error.localizedDescription)
        }
        isSaving = false
    }

    private func retrySyncOnly() async {
        let result = workoutState.buildResult(feeling: 0, journal: journal, sleepHours: 0)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let jsonData = try? encoder.encode(result) else { return }
        githubStep = .running
        do {
            _ = try await homeVM.githubService.pushFileWithDedup(
                owner: homeVM.githubOwner, repo: homeVM.githubRepo,
                token: homeVM.githubToken, directory: homeVM.inboxPath,
                baseName: result.date, content: jsonData,
                commitMessage: "[FitSync] workout \(result.date)")
            githubStep = .done
        } catch {
            githubStep = .failed(error.localizedDescription)
        }
    }

    private func handleDone() {
        workoutState.clearSnapshot()
        workoutState.reset()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: .dismissToHome, object: nil)
        }
    }
}
