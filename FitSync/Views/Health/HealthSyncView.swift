import SwiftUI

struct HealthSyncView: View {
    var syncVM: SyncViewModel
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    lastSyncInfo

                    if !syncVM.pendingItems.isEmpty {
                        pendingSection
                    }

                    syncButton

                    NavigationLink("同步历史 →", destination: SyncHistoryView(syncVM: syncVM))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("健康数据同步")
            .task { await syncVM.refreshState() }
        }
    }

    private var lastSyncInfo: some View {
        VStack(spacing: 4) {
            if let text = syncVM.lastSyncDisplayText {
                Text("上次同步").font(.caption).foregroundStyle(.secondary)
                Text(text).font(.headline)
            } else {
                Text("尚未同步过").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("待同步数据").font(.headline)
            ForEach(syncVM.pendingItems) { item in
                HStack {
                    Image(systemName: item.icon)
                        .frame(width: 24)
                    Text(item.label)
                    Spacer()
                    Text("\(item.count) \(item.unit)")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var syncButton: some View {
        Group {
            switch syncVM.syncState {
            case .notConfigured:
                VStack(spacing: 8) {
                    Text("请先在设置中配置 GitHub").foregroundStyle(.secondary)
                }
            case .verifying:
                ProgressView("正在验证连接...")
            case .verifyFailed(let msg):
                VStack(spacing: 8) {
                    Label(msg, systemImage: "xmark.circle").foregroundStyle(.red)
                    Button("重试") { Task { await syncVM.refreshState() } }
                        .buttonStyle(.bordered)
                }
            case .ready:
                Button {
                    Task { await syncVM.sync() }
                } label: {
                    Label("同步到 GitHub", systemImage: "arrow.triangle.2.circlepath")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            case .noNewData:
                Label("暂无新数据", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
                Button("强制重新同步") {
                    syncVM.resetSyncDate()
                    Task { await syncVM.refreshState() }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            case .syncing(let phase):
                VStack(spacing: 8) {
                    ProgressView()
                    switch phase {
                    case .reading: Text("正在读取健康数据...")
                    case .formatting: Text("正在格式化...")
                    case .pushing: Text("正在推送到 GitHub...")
                    }
                }
                .font(.subheadline).foregroundStyle(.secondary)
            case .success(let count, let size):
                VStack(spacing: 4) {
                    Label("同步完成", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("\(count) 条记录 · \(size)").font(.caption).foregroundStyle(.secondary)
                }
            case .failed(let msg):
                VStack(spacing: 8) {
                    Label("同步失败", systemImage: "xmark.circle").foregroundStyle(.red)
                    Text(msg).font(.caption).foregroundStyle(.secondary)
                    Button("重试") { Task { await syncVM.sync() } }
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}
