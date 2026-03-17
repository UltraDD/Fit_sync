import Foundation
import HealthKit
import Observation

enum ConnectionStatus {
    case connected, invalidToken, noConfig, offline
}

enum UploadPhase: Equatable {
    case idle
    case uploadingResult
    case resultUploaded
    case syncingHealth(SyncPhase)
    case allDone(resultPath: String, healthRecords: Int)
    case resultFailed(String)
    case healthFailed(String)
}

@Observable
final class HomeViewModel {
    var plan: PlanJSON?
    var syncing = false
    var lastSync: String?
    var connectionStatus: ConnectionStatus = .noConfig
    var planCompleted = false
    var uploadPhase: UploadPhase = .idle

    private let githubService = GitHubService()
    private let syncViewModel: SyncViewModel

    var githubOwner: String { UserDefaults.standard.string(forKey: "github_owner") ?? "" }
    var githubRepo: String { UserDefaults.standard.string(forKey: "github_repo") ?? "" }
    var githubToken: String { KeychainHelper.read("github_token") ?? "" }
    var outboxPath: String { UserDefaults.standard.string(forKey: "outbox_path") ?? "fitness/exchange/outbox" }
    var inboxPath: String { UserDefaults.standard.string(forKey: "inbox_path") ?? "fitness/exchange/inbox" }
    var isConfigured: Bool { !githubOwner.isEmpty && !githubRepo.isEmpty && !githubToken.isEmpty }

    init(syncViewModel: SyncViewModel) {
        self.syncViewModel = syncViewModel
    }

    func fetchPlan() async {
        guard isConfigured else { connectionStatus = .noConfig; return }
        syncing = true
        defer { syncing = false }

        do {
            try await githubService.testConnection(owner: githubOwner, repo: githubRepo, token: githubToken)
            connectionStatus = .connected
        } catch is GitHubError {
            connectionStatus = .invalidToken
            return
        } catch {
            connectionStatus = .offline
            return
        }

        do {
            let files = try await githubService.listFiles(owner: githubOwner, repo: githubRepo, token: githubToken, path: outboxPath)
            let jsonFiles = files.filter { $0.name.hasSuffix(".json") }.sorted { $0.name > $1.name }
            guard let latest = jsonFiles.first else { plan = nil; return }

            if let data = try await githubService.fetchFileContent(owner: githubOwner, repo: githubRepo, token: githubToken, path: latest.path) {
                let decoded = try JSONDecoder().decode(PlanJSON.self, from: data)
                if decoded.schema == "my_life.fitness.plan" {
                    plan = decoded
                }
            }
        } catch {
            plan = nil
        }

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        lastSync = timeFmt.string(from: Date())
    }

    func importPlan(json: String) throws -> PlanJSON {
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PlanJSON.self, from: data)
        guard decoded.schema == "my_life.fitness.plan" else {
            throw NSError(domain: "FitSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "无效格式：schema 不匹配"])
        }
        plan = decoded
        return decoded
    }

    func uploadResultAndSyncHealth(result: ResultJSON) async {
        guard isConfigured else { uploadPhase = .resultFailed("GitHub 未配置"); return }

        uploadPhase = .uploadingResult

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let jsonData = try? encoder.encode(result) else {
            uploadPhase = .resultFailed("JSON 编码失败")
            return
        }

        do {
            let path = try await githubService.pushFileWithDedup(
                owner: githubOwner, repo: githubRepo, token: githubToken,
                directory: inboxPath, baseName: result.date, content: jsonData,
                commitMessage: "[FitSync] workout \(result.date)"
            )
            uploadPhase = .resultUploaded

            if HKHealthStore.isHealthDataAvailable() {
                uploadPhase = .syncingHealth(.reading)
                let success = await syncViewModel.sync(lookbackDays: 7)
                if success {
                    if case .success(let count, _) = syncViewModel.syncState {
                        uploadPhase = .allDone(resultPath: path, healthRecords: count)
                    } else {
                        uploadPhase = .allDone(resultPath: path, healthRecords: 0)
                    }
                } else {
                    uploadPhase = .healthFailed(syncViewModel.syncState == .failed("") ? "同步失败" : "健康数据同步失败")
                }
            } else {
                uploadPhase = .allDone(resultPath: path, healthRecords: 0)
            }
        } catch {
            uploadPhase = .resultFailed(error.localizedDescription)
        }
    }
}
