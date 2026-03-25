import SwiftUI

struct SettingsView: View {
    @State private var repoFullName: String = ""
    @State private var token: String = ""
    @State private var outboxPath: String = "fitness/exchange/outbox"
    @State private var inboxPath: String = "fitness/exchange/inbox"
    @State private var testResult: TestResult?
    @State private var testing = false
    @State private var showTokenHelp = false

    enum TestResult {
        case success, failure(String)
    }

    var body: some View {
        ZStack {
            FLColor.bg.ignoresSafeArea()
        Form {
            Section("GitHub 配置") {
                TextField("仓库（如 username/My_life）", text: $repoFullName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Personal Access Token", text: $token)

                Button {
                    showTokenHelp.toggle()
                } label: {
                    HStack {
                        Text("如何创建 Token？")
                            .font(.caption)
                        Image(systemName: showTokenHelp ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                if showTokenHelp {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. 前往 GitHub → Settings → Developer settings")
                        Text("2. Personal access tokens → Fine-grained tokens")
                        Text("3. 选择对应仓库，权限选 Contents: Read and write")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Section("路径配置") {
                TextField("计划目录（outbox）", text: $outboxPath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("上传目录（inbox）", text: $inboxPath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                NavigationLink {
                    HealthSyncView(syncVM: SyncViewModel())
                } label: {
                    Label("健康数据同步", systemImage: "heart.text.clipboard")
                }
            }

            Section {
                Button {
                    save()
                    testConnection()
                } label: {
                    HStack {
                        Text("测试连接")
                        Spacer()
                        if testing {
                            ProgressView().controlSize(.small)
                        } else if let result = testResult {
                            switch result {
                            case .success:
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            case .failure:
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                            }
                        }
                    }
                }
                .disabled(repoFullName.isEmpty || token.isEmpty)

                if case .failure(let msg) = testResult {
                    Text(msg).font(.caption).foregroundStyle(.red)
                }
                if case .success = testResult {
                    Text("已连接").font(.caption).foregroundStyle(.green)
                }
            }
        }
        .scrollContentBackground(.hidden)
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { load() }
        .onDisappear { save() }
    }

    private var parsedOwner: String {
        let parts = repoFullName.split(separator: "/", maxSplits: 1)
        return parts.count >= 1 ? String(parts[0]) : ""
    }

    private var parsedRepo: String {
        let parts = repoFullName.split(separator: "/", maxSplits: 1)
        return parts.count >= 2 ? String(parts[1]) : ""
    }

    private func load() {
        let owner = UserDefaults.standard.string(forKey: "github_owner") ?? ""
        let repo = UserDefaults.standard.string(forKey: "github_repo") ?? ""
        if !owner.isEmpty && !repo.isEmpty {
            repoFullName = "\(owner)/\(repo)"
        }
        token = KeychainHelper.read("github_token") ?? ""
        outboxPath = UserDefaults.standard.string(forKey: "outbox_path") ?? "fitness/exchange/outbox"
        inboxPath = UserDefaults.standard.string(forKey: "inbox_path") ?? "fitness/exchange/inbox"
    }

    private func save() {
        UserDefaults.standard.set(parsedOwner, forKey: "github_owner")
        UserDefaults.standard.set(parsedRepo, forKey: "github_repo")
        KeychainHelper.save(token, for: "github_token")
        UserDefaults.standard.set(outboxPath, forKey: "outbox_path")
        UserDefaults.standard.set(inboxPath, forKey: "inbox_path")
    }

    private func testConnection() {
        testing = true
        testResult = nil
        Task {
            do {
                try await GitHubService().testConnection(
                    owner: parsedOwner, repo: parsedRepo, token: token)
                testResult = .success
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            testing = false
        }
    }
}
