import SwiftUI

struct SettingsView: View {
    @State private var owner: String = ""
    @State private var repo: String = ""
    @State private var token: String = ""
    @State private var outboxPath: String = "fitness/exchange/outbox"
    @State private var inboxPath: String = "fitness/exchange/inbox"
    @State private var syncPath: String = "fitness/health/sync/"
    @State private var testResult: TestResult?
    @State private var testing = false

    enum TestResult {
        case success, failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("GitHub 配置") {
                    TextField("仓库拥有者", text: $owner)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    TextField("仓库名", text: $repo)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    SecureField("Personal Access Token", text: $token)
                }

                Section("路径配置") {
                    TextField("计划目录", text: $outboxPath)
                        .autocapitalization(.none)
                    TextField("上传目录", text: $inboxPath)
                        .autocapitalization(.none)
                    TextField("健康同步目录", text: $syncPath)
                        .autocapitalization(.none)
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
                    .disabled(owner.isEmpty || repo.isEmpty || token.isEmpty)

                    if case .failure(let msg) = testResult {
                        Text(msg).font(.caption).foregroundStyle(.red)
                    }
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("签名")
                        Spacer()
                        Text("免费签名（7天有效）").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .onAppear { load() }
        }
    }

    private func load() {
        owner = UserDefaults.standard.string(forKey: "github_owner") ?? ""
        repo = UserDefaults.standard.string(forKey: "github_repo") ?? ""
        token = KeychainHelper.read("github_token") ?? ""
        outboxPath = UserDefaults.standard.string(forKey: "outbox_path") ?? "fitness/exchange/outbox"
        inboxPath = UserDefaults.standard.string(forKey: "inbox_path") ?? "fitness/exchange/inbox"
        syncPath = UserDefaults.standard.string(forKey: "sync_path") ?? "fitness/health/sync/"
    }

    private func save() {
        UserDefaults.standard.set(owner, forKey: "github_owner")
        UserDefaults.standard.set(repo, forKey: "github_repo")
        KeychainHelper.save(token, for: "github_token")
        UserDefaults.standard.set(outboxPath, forKey: "outbox_path")
        UserDefaults.standard.set(inboxPath, forKey: "inbox_path")
        UserDefaults.standard.set(syncPath, forKey: "sync_path")
    }

    private func testConnection() {
        testing = true
        testResult = nil
        Task {
            do {
                try await GitHubService().testConnection(owner: owner, repo: repo, token: token)
                testResult = .success
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            testing = false
        }
    }
}
