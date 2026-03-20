import SwiftUI

struct WorkoutFinishView: View {
    @Bindable var workoutState: WorkoutState
    var homeVM: HomeViewModel
    @State private var feeling: Int = 7
    @State private var sleepHours: Double = 7.0
    @State private var journal: String = ""
    @State private var saved = false
    @State private var saving = false
    @State private var saveError = ""
    @State private var syncStatus: SyncStatus = .idle
    @State private var restored = false
    @Environment(\.dismiss) private var dismiss

    enum SyncStatus { case idle, syncing, success, queued, failed }

    private var totalSets: Int {
        workoutState.exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
    }
    private var maxWeight: Double { workoutState.maxWeight }
    private var durationMin: Int { workoutState.elapsedSeconds / 60 }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 20) {
                    Text("训练完成!")
                        .font(.largeTitle.bold())
                        .padding(.top, 16)

                    summarySection
                    feelingSection
                    sleepSection
                    journalSection

                    if !saved {
                        saveSection
                    } else {
                        syncResultSection
                    }

                    if saved {
                        exportButton
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

    // MARK: - Feeling

    private var feelingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("今天练得怎么样？")
                .font(.subheadline).foregroundStyle(FLColor.text60)

            HStack(spacing: 6) {
                ForEach(1...10, id: \.self) { n in
                    Button {
                        feeling = n
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("\(n)")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 32, height: 32)
                            .background(feeling == n ? FLColor.green : Color.white.opacity(0.08))
                            .foregroundStyle(feeling == n ? .black : FLColor.text40)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .scaleEffect(feeling == n ? 1.1 : 1)
                    }
                }
            }
        }
        .glassCard(padding: 24)
    }

    // MARK: - Sleep

    private var sleepSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("昨晚睡了多久？").font(.subheadline).foregroundStyle(FLColor.text50)
                Spacer()
                Text("\(sleepHours, specifier: "%.1f") 小时")
                    .font(.title3.weight(.semibold).monospacedDigit())
            }
            Slider(value: $sleepHours, in: 3...12, step: 0.5)
                .tint(FLColor.green.opacity(0.6))
        }
        .glassCard()
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

    // MARK: - Save

    private var saveSection: some View {
        VStack(spacing: 8) {
            Button {
                Task { await handleSaveAndSync() }
            } label: {
                if saving {
                    ProgressView().tint(.black)
                } else {
                    Text("保存并同步")
                }
            }
            .buttonStyle(GreenButtonStyle())
            .disabled(saving || workoutState.exercises.isEmpty)
            .opacity(saving || workoutState.exercises.isEmpty ? 0.4 : 1)

            if !saveError.isEmpty {
                Text(saveError).font(.caption).foregroundStyle(FLColor.red)
            }
        }
    }

    // MARK: - Sync Result

    @ViewBuilder
    private var syncResultSection: some View {
        VStack(spacing: 14) {
            switch syncStatus {
            case .success:
                Label("已保存并同步到 GitHub", systemImage: "checkmark.circle.fill")
                    .font(.headline).foregroundStyle(FLColor.green)
            case .failed:
                Label("已保存到本地", systemImage: "checkmark.circle.fill")
                    .font(.headline).foregroundStyle(FLColor.green)
                Text("GitHub 同步失败").font(.caption).foregroundStyle(FLColor.red)
                Button("重试同步") {
                    Task { await retrySyncOnly() }
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: false))
            default:
                Label("已保存到本地", systemImage: "checkmark.circle.fill")
                    .font(.headline).foregroundStyle(FLColor.green)
            }

            Button("返回首页") { handleDone() }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var exportButton: some View {
        Button("复制到剪贴板") {
            let result = workoutState.buildResult(feeling: feeling, journal: journal, sleepHours: sleepHours)
            if let data = try? JSONEncoder().encode(result), let str = String(data: data, encoding: .utf8) {
                UIPasteboard.general.string = str
            }
        }
        .font(.subheadline).foregroundStyle(FLColor.text40)
    }

    // MARK: - Actions

    private func handleSaveAndSync() async {
        saving = true
        saveError = ""
        let result = workoutState.buildResult(feeling: feeling, journal: journal, sleepHours: sleepHours)
        WorkoutStore.shared.save(result)
        workoutState.clearDraft()
        saved = true

        if homeVM.isConfigured {
            syncStatus = .syncing
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let jsonData = try? encoder.encode(result) else {
                syncStatus = .failed; saving = false; return
            }
            do {
                _ = try await homeVM.githubService.pushFileWithDedup(
                    owner: homeVM.githubOwner, repo: homeVM.githubRepo,
                    token: homeVM.githubToken, directory: homeVM.inboxPath,
                    baseName: result.date, content: jsonData,
                    commitMessage: "[FitSync] workout \(result.date)")
                syncStatus = .success
            } catch { syncStatus = .failed }
        } else { syncStatus = .idle }
        saving = false
    }

    private func retrySyncOnly() async {
        let result = workoutState.buildResult(feeling: feeling, journal: journal, sleepHours: sleepHours)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let jsonData = try? encoder.encode(result) else { return }
        syncStatus = .syncing
        do {
            _ = try await homeVM.githubService.pushFileWithDedup(
                owner: homeVM.githubOwner, repo: homeVM.githubRepo,
                token: homeVM.githubToken, directory: homeVM.inboxPath,
                baseName: result.date, content: jsonData,
                commitMessage: "[FitSync] workout \(result.date)")
            syncStatus = .success
        } catch { syncStatus = .failed }
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
