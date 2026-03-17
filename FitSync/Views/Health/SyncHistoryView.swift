import SwiftUI

struct SyncHistoryView: View {
    var syncVM: SyncViewModel

    var body: some View {
        List {
            if syncVM.syncHistory.isEmpty {
                Text("还没有同步记录").foregroundStyle(.secondary)
            } else {
                ForEach(syncVM.syncHistory) { entry in
                    HStack {
                        Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(entry.success ? .green : .red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DateUtils.shortDateTime.string(from: entry.date))
                                .font(.subheadline)
                            if entry.success {
                                Text("\(entry.recordCount) 条 · \(DateUtils.formatBytes(entry.fileSize))")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else if let msg = entry.errorMessage {
                                Text(msg).font(.caption).foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("同步历史")
        .navigationBarTitleDisplayMode(.inline)
    }
}
