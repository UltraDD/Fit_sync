import SwiftUI

struct WorkoutHistoryView: View {
    @State private var history: [ResultJSON] = []
    @State private var expandedDate: String?
    @State private var deletingDate: String?
    @State private var syncing = false
    @State private var syncMsg = ""

    private var thisMonthCount: Int {
        let ym = String(DateUtils.dateOnly.string(from: Date()).prefix(7))
        return history.filter { $0.date.hasPrefix(ym) }.count
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 16) {
                    if !history.isEmpty { statsSection }
                    syncFromGitHubSection
                    if history.isEmpty { emptyState } else { historyList }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("历史记录")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadHistory() }
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("\(history.count)")
                    .font(.title2.bold()).monospacedDigit()
                Text("总训练").font(.caption).foregroundStyle(FLColor.text40)
            }
            .frame(maxWidth: .infinity)
            .glassCard(padding: 16)

            VStack(spacing: 4) {
                Text("\(thisMonthCount)")
                    .font(.title2.bold()).monospacedDigit()
                Text("本月").font(.caption).foregroundStyle(FLColor.text40)
            }
            .frame(maxWidth: .infinity)
            .glassCard(padding: 16)
        }
    }

    // MARK: - Sync

    private var syncFromGitHubSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("从 GitHub 云端同步").font(.subheadline).foregroundStyle(.white)
                if !syncMsg.isEmpty {
                    Text(syncMsg)
                        .font(.caption)
                        .foregroundStyle(syncMsg.contains("失败") ? FLColor.red : FLColor.green)
                }
            }
            Spacer()
            Button {
                Task { await syncFromGitHub() }
            } label: {
                if syncing {
                    ProgressView().controlSize(.small)
                } else {
                    Text("拉取")
                        .font(.caption.weight(.medium))
                }
            }
            .buttonStyle(SecondaryButtonStyle(fullWidth: false))
            .disabled(syncing)
        }
        .glassCard(padding: 16)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "dumbbell").font(.largeTitle).foregroundStyle(FLColor.text20)
            Text("暂无训练记录").font(.headline).foregroundStyle(FLColor.text40)
            Text("完成一次训练后这里会显示历史")
                .font(.subheadline).foregroundStyle(FLColor.text30)
        }
        .padding(.vertical, 40)
    }

    // MARK: - History List

    private var groupedHistory: [(month: String, workouts: [ResultJSON])] {
        let grouped = Dictionary(grouping: history) { w in
            String(w.date.prefix(7))
        }
        return grouped.sorted { $0.key > $1.key }.map { (month: $0.key, workouts: $0.value) }
    }

    private func monthLabel(_ ym: String) -> String {
        let parts = ym.split(separator: "-")
        guard parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) else { return ym }
        let currentYear = Calendar.current.component(.year, from: Date())
        if y == currentYear {
            return "\(m) 月"
        }
        return "\(y) 年 \(m) 月"
    }

    private var historyList: some View {
        VStack(spacing: 20) {
            ForEach(groupedHistory, id: \.month) { group in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(monthLabel(group.month))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(FLColor.text40)
                        Spacer()
                        Text("\(group.workouts.count) 次")
                            .font(.caption)
                            .foregroundStyle(FLColor.text30)
                    }
                    .padding(.horizontal, 4)

                    ForEach(group.workouts, id: \.uniqueId) { workout in
                        workoutCard(workout)
                    }
                }
            }
        }
    }

    private func workoutCard(_ workout: ResultJSON) -> some View {
        let isExpanded = expandedDate == workout.uniqueId
        let isDeleting = deletingDate == workout.uniqueId

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedDate = isExpanded ? nil : workout.uniqueId
                    deletingDate = nil
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.date).font(.subheadline.bold())
                        HStack(spacing: 8) {
                            Text("\(workout.exercises.count) 个动作")
                            if workout.duration_minutes > 0 {
                                Text("· \(workout.duration_minutes)分钟")
                            }
                            if !workout.start_time.isEmpty && !workout.end_time.isEmpty {
                                Text("· \(workout.start_time)-\(workout.end_time)")
                            }
                        }
                        .font(.caption).foregroundStyle(FLColor.text40)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(16)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle().fill(FLColor.cardBorder).frame(height: 1)

                    ForEach(Array(workout.exercises.enumerated()), id: \.offset) { _, ex in
                        HStack {
                            Text(ex.name).font(.subheadline).foregroundStyle(.white)
                            Spacer()
                            if ex.type == "strength", let sets = ex.sets, !sets.isEmpty {
                                let maxKg = sets.map(\.weight_kg).max() ?? 0
                                Text("\(sets.count)组 · 最大\(maxKg.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", maxKg) : String(format: "%.1f", maxKg))kg")
                                    .font(.caption).foregroundStyle(FLColor.text40).monospacedDigit()
                            } else if let cardio = ex.cardio_data {
                                Text("\(Int(cardio.duration_minutes))分钟")
                                    .font(.caption).foregroundStyle(FLColor.text40)
                            }
                        }
                    }

                    if !workout.journal.isEmpty {
                        Rectangle().fill(FLColor.cardBorder).frame(height: 1)
                        Text(workout.journal)
                            .font(.caption).foregroundStyle(FLColor.text40).italic()
                    }

                    Rectangle().fill(FLColor.cardBorder).frame(height: 1)

                    if !isDeleting {
                        Button("删除此记录") { deletingDate = workout.uniqueId }
                            .font(.caption).foregroundStyle(FLColor.red.opacity(0.7))
                    } else {
                        HStack(spacing: 12) {
                            Button("确认删除") { deleteWorkout(workout) }
                                .buttonStyle(DangerButtonStyle())
                            Button("取消") { deletingDate = nil }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 24).fill(FLColor.cardBg))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(FLColor.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func loadHistory() { history = WorkoutStore.shared.history }

    private func deleteWorkout(_ workout: ResultJSON) {
        if let idx = history.firstIndex(where: { $0.uniqueId == workout.uniqueId }) {
            WorkoutStore.shared.deleteWorkout(at: idx)
            expandedDate = nil
            deletingDate = nil
            loadHistory()
        }
    }

    private func syncFromGitHub() async {
        syncing = true
        syncMsg = ""
        let owner = UserDefaults.standard.string(forKey: "github_owner") ?? ""
        let repo = UserDefaults.standard.string(forKey: "github_repo") ?? ""
        let token = KeychainHelper.read("github_token") ?? ""
        let inboxPath = UserDefaults.standard.string(forKey: "inbox_path") ?? "fitness/exchange/inbox"

        guard !owner.isEmpty, !repo.isEmpty, !token.isEmpty else {
            syncMsg = "请先配置 GitHub"
            syncing = false
            return
        }

        do {
            let github = GitHubService()
            let files = try await github.listFiles(owner: owner, repo: repo, token: token, path: inboxPath)
            let jsonFiles = files.filter { $0.name.contains(".json") }

            if jsonFiles.isEmpty {
                syncMsg = "云端没有找到训练记录"
                syncing = false
                return
            }

            let beforeCount = WorkoutStore.shared.history.count
            let localIds = Set(WorkoutStore.shared.history.map { "\($0.date)|\($0.start_time)" })

            for file in jsonFiles {
                guard let data = try await github.fetchFileContent(
                    owner: owner, repo: repo, token: token, path: file.path) else { continue }
                if let result = try? JSONDecoder().decode(ResultJSON.self, from: data) {
                    let id = "\(result.date)|\(result.start_time)"
                    if !localIds.contains(id) {
                        WorkoutStore.shared.save(result)
                    }
                }
            }

            let imported = WorkoutStore.shared.history.count - beforeCount
            syncMsg = imported > 0 ? "已从云端导入 \(imported) 条记录" : "本地已包含所有云端记录"
            if imported > 0 { loadHistory() }
        } catch {
            syncMsg = "同步失败: \(error.localizedDescription)"
        }
        syncing = false
    }
}

extension ResultJSON {
    var uniqueId: String { "\(date)_\(start_time)" }
}
