import SwiftUI

struct WorkoutFinishView: View {
    @Bindable var workoutState: WorkoutState
    var homeVM: HomeViewModel
    @State private var feeling: Int = 7
    @State private var sleepHours: Double = 7.0
    @State private var journal: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("训练完成").font(.largeTitle.bold())

                summarySection

                ratingSection

                sleepSection

                journalSection

                uploadSection

                Button("复制到剪贴板") {
                    let result = workoutState.buildResult(feeling: feeling, journal: journal, sleepHours: sleepHours)
                    if let data = try? JSONEncoder().encode(result), let str = String(data: data, encoding: .utf8) {
                        UIPasteboard.general.string = str
                    }
                    WorkoutStore.shared.save(result)
                }
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("训练总结")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            journal = workoutState.journalText
        }
    }

    private var summarySection: some View {
        HStack(spacing: 24) {
            statItem("\(workoutState.elapsedSeconds / 60)", label: "分钟")
            statItem("\(workoutState.exercises.count)", label: "动作")
            statItem("\(workoutState.totalCompletedSets)", label: "组")
            if let (weight, name) = workoutState.maxWeight {
                statItem(String(format: "%.1fkg", weight), label: name)
            }
        }
    }

    private func statItem(_ value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日评分").font(.headline)
            HStack(spacing: 8) {
                ForEach(1...10, id: \.self) { n in
                    Button {
                        feeling = n
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("\(n)")
                            .font(.body.bold())
                            .frame(width: 36, height: 36)
                            .background(feeling == n ? Color.accentColor : Color.clear)
                            .foregroundStyle(feeling == n ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                    }
                }
            }
        }
    }

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("昨晚睡眠").font(.headline)
                Spacer()
                Text("\(sleepHours, specifier: "%.1f") 小时")
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: $sleepHours, in: 3...12, step: 0.5)
        }
    }

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("训练随笔").font(.headline)
            TextField("记录今天的训练感受...", text: $journal, axis: .vertical)
                .lineLimit(3...8)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var uploadSection: some View {
        VStack(spacing: 12) {
            switch homeVM.uploadPhase {
            case .idle:
                Button {
                    let result = workoutState.buildResult(feeling: feeling, journal: journal, sleepHours: sleepHours)
                    WorkoutStore.shared.save(result)
                    Task { await homeVM.uploadResultAndSyncHealth(result: result) }
                } label: {
                    Label("上传并同步", systemImage: "icloud.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            case .uploadingResult:
                uploadProgress(step1: .inProgress, step2: .pending)

            case .resultUploaded:
                uploadProgress(step1: .done, step2: .pending)

            case .syncingHealth:
                uploadProgress(step1: .done, step2: .inProgress)

            case .allDone(_, let healthRecords):
                uploadProgress(step1: .done, step2: .done)
                if healthRecords > 0 {
                    Text("健康数据已同步（\(healthRecords) 条）").font(.caption).foregroundStyle(.green)
                }
                Button("完成") {
                    let result = workoutState.buildResult(feeling: feeling, journal: journal, sleepHours: sleepHours)
                    WorkoutStore.shared.save(result)
                    workoutState.reset()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            case .resultFailed(let msg):
                Text(msg).foregroundStyle(.red).font(.caption)
                Button("重试") {
                    homeVM.uploadPhase = .idle
                }
                .buttonStyle(.bordered)

            case .healthFailed(let msg):
                uploadProgress(step1: .done, step2: .failed)
                Text(msg).foregroundStyle(.orange).font(.caption)
                HStack {
                    Button("重试健康同步") {
                        let result = workoutState.buildResult(feeling: feeling, journal: journal, sleepHours: sleepHours)
                        Task { await homeVM.uploadResultAndSyncHealth(result: result) }
                    }
                    .buttonStyle(.bordered)
                    Button("跳过") {
                        workoutState.reset()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            }
        }
    }

    enum StepStatus { case pending, inProgress, done, failed }

    private func uploadProgress(step1: StepStatus, step2: StepStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            stepRow("上传训练记录", status: step1)
            stepRow("同步健康数据（近7天）", status: step2)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func stepRow(_ text: String, status: StepStatus) -> some View {
        HStack(spacing: 8) {
            switch status {
            case .pending:
                Image(systemName: "circle").foregroundStyle(.secondary)
            case .inProgress:
                ProgressView().controlSize(.small)
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            }
            Text(text).font(.subheadline)
        }
    }
}
