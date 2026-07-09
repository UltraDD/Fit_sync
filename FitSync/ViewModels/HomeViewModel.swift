import Foundation
import HealthKit
import Observation

enum ConnectionStatus {
    case connected, invalidToken, noConfig, offline
}

@Observable
@MainActor
final class HomeViewModel {
    var plan: PlanJSON?
    var syncing = false
    var lastSync: String?
    var connectionStatus: ConnectionStatus = .noConfig
    var planCompleted = false
    var isEvaluatingState = false

    let githubService = GitHubService()
    private var syncingInbox = false

    private enum CacheKey {
        static let plan = "home_cached_plan"
        static let lastSync = "home_cached_plan_last_sync"
    }

    init() {
        loadCachedPlan()
    }

    var githubOwner: String { UserDefaults.standard.string(forKey: "github_owner") ?? "" }
    var githubRepo: String { UserDefaults.standard.string(forKey: "github_repo") ?? "" }
    var githubToken: String { KeychainHelper.read("github_token") ?? "" }
    var outboxPath: String { UserDefaults.standard.string(forKey: "outbox_path") ?? "fitness/exchange/outbox" }
    var inboxPath: String { UserDefaults.standard.string(forKey: "inbox_path") ?? "fitness/exchange/inbox" }
    var isConfigured: Bool { !githubOwner.isEmpty && !githubRepo.isEmpty && !githubToken.isEmpty }

    func fetchPlan() async {
        guard isConfigured else { connectionStatus = .noConfig; return }
        guard !syncing else { return }
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
            guard let latest = jsonFiles.first else {
                plan = nil
                planCompleted = false
                clearCachedPlan()
                return
            }

            if let data = try await githubService.fetchFileContent(owner: githubOwner, repo: githubRepo, token: githubToken, path: latest.path) {
                let decoded = try JSONDecoder().decode(PlanJSON.self, from: data)
                if decoded.schema == "my_life.fitness.plan" {
                    plan = decoded
                    checkPlanCompleted(decoded)
                }
            }
        } catch {
            // Keep existing plan on network errors; don't clear valid data
        }

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        lastSync = timeFmt.string(from: Date())
        if let plan {
            saveCachedPlan(plan)
        }

        Task { await syncInboxResultsAfterPlanPull() }
    }

    func importPlan(json: String) throws -> PlanJSON {
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PlanJSON.self, from: data)
        guard decoded.schema == "my_life.fitness.plan" else {
            throw NSError(domain: "FitSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "无效格式：schema 不匹配"])
        }
        plan = decoded
        checkPlanCompleted(decoded)
        saveCachedPlan(decoded)
        return decoded
    }

    func recheckPlanCompleted() {
        guard let plan = plan else { return }
        checkPlanCompleted(plan)
    }

    private func checkPlanCompleted(_ plan: PlanJSON) {
        // Check by plan_ref or by matching date in local history
        planCompleted = WorkoutStore.shared.history.contains {
            $0.plan_ref == plan.date || $0.date == plan.date
        }
    }

    private func loadCachedPlan() {
        guard let data = UserDefaults.standard.data(forKey: CacheKey.plan),
              let cached = try? JSONDecoder().decode(PlanJSON.self, from: data),
              cached.schema == "my_life.fitness.plan" else { return }

        plan = cached
        lastSync = UserDefaults.standard.string(forKey: CacheKey.lastSync)
        connectionStatus = isConfigured ? .connected : .noConfig
        checkPlanCompleted(cached)
    }

    private func saveCachedPlan(_ plan: PlanJSON) {
        guard let data = try? JSONEncoder().encode(plan) else { return }
        UserDefaults.standard.set(data, forKey: CacheKey.plan)
        if let lastSync {
            UserDefaults.standard.set(lastSync, forKey: CacheKey.lastSync)
        } else {
            UserDefaults.standard.removeObject(forKey: CacheKey.lastSync)
        }
    }

    private func clearCachedPlan() {
        UserDefaults.standard.removeObject(forKey: CacheKey.plan)
        UserDefaults.standard.removeObject(forKey: CacheKey.lastSync)
    }

    /// Auto-import recent results from GitHub inbox into local WorkoutStore.
    private func syncInboxResultsAfterPlanPull() async {
        guard !syncingInbox else { return }
        syncingInbox = true
        defer { syncingInbox = false }

        await syncInboxResults()
        recheckPlanCompleted()
    }

    private func syncInboxResults() async {
        do {
            let files = try await githubService.listFiles(
                owner: githubOwner, repo: githubRepo,
                token: githubToken, path: inboxPath)
            let jsonFiles = files.filter { $0.name.contains(".json") }
                .sorted { $0.name > $1.name }

            var localIds = Set(WorkoutStore.shared.history.map { "\($0.date)|\($0.start_time)" })

            for file in jsonFiles {
                guard let data = try await githubService.fetchFileContent(
                    owner: githubOwner, repo: githubRepo,
                    token: githubToken, path: file.path) else { continue }

                if let result = try? JSONDecoder().decode(ResultJSON.self, from: data) {
                    let id = "\(result.date)|\(result.start_time)"
                    if !localIds.contains(id) {
                        localIds.insert(id)
                        WorkoutStore.shared.save(result)
                    }
                }
            }
        } catch { }
    }
}
