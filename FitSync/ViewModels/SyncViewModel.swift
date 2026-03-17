import Foundation
import HealthKit
import Observation

enum SyncPhase {
    case reading, formatting, pushing
}

enum SyncState: Equatable {
    case notConfigured
    case verifying
    case verifyFailed(String)
    case ready
    case noNewData
    case syncing(SyncPhase)
    case success(recordCount: Int, fileSize: String)
    case failed(String)

    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.notConfigured, .notConfigured),
             (.verifying, .verifying),
             (.ready, .ready),
             (.noNewData, .noNewData): return true
        case (.verifyFailed(let a), .verifyFailed(let b)): return a == b
        case (.syncing(let a), .syncing(let b)):
            switch (a, b) {
            case (.reading, .reading), (.formatting, .formatting), (.pushing, .pushing): return true
            default: return false
            }
        case (.success(let a1, let a2), .success(let b1, let b2)): return a1 == b1 && a2 == b2
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

struct PendingDataItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let count: Int
    let unit: String
}

@Observable
final class SyncViewModel {
    var syncState: SyncState = .notConfigured
    var lastSyncDate: Date?
    var pendingItems: [PendingDataItem] = []
    var syncHistory: [SyncHistoryEntry] = []

    private let healthService = HealthKitService()
    private let githubService = GitHubService()
    private let iso = ISO8601DateFormatter()

    var githubOwner: String { UserDefaults.standard.string(forKey: "github_owner") ?? "" }
    var githubRepo: String { UserDefaults.standard.string(forKey: "github_repo") ?? "" }
    var githubToken: String { KeychainHelper.read("github_token") ?? "" }
    var syncPath: String { UserDefaults.standard.string(forKey: "sync_path") ?? "fitness/health/sync/" }
    var isConfigured: Bool { !githubOwner.isEmpty && !githubRepo.isEmpty && !githubToken.isEmpty }

    init() {
        iso.formatOptions = [.withInternetDateTime]
        loadLastSyncDate()
        loadSyncHistory()
    }

    func refreshState() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        if !isConfigured { syncState = .notConfigured; pendingItems = []; return }

        syncState = .verifying
        do {
            try await githubService.testConnection(owner: githubOwner, repo: githubRepo, token: githubToken)
        } catch {
            syncState = .verifyFailed(error.localizedDescription)
            return
        }

        await loadPendingItems()
        syncState = pendingItems.isEmpty ? .noNewData : .ready
    }

    @discardableResult
    func sync(lookbackDays: Int = 7) async -> Bool {
        guard isConfigured else { return false }

        let start = lastSyncDate ?? Calendar.current.date(byAdding: .day, value: -lookbackDays, to: .now)!
        let end = Date.now

        syncState = .syncing(.reading)
        let payload: SyncPayload
        do { payload = try await buildSyncPayload(start: start, end: end) }
        catch { handleFailure("读取健康数据失败：\(error.localizedDescription)"); return false }

        syncState = .syncing(.formatting)
        let jsonData: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            jsonData = try encoder.encode(payload)
        } catch { handleFailure("JSON 编码失败"); return false }

        syncState = .syncing(.pushing)
        let filePath = "\(syncPath)\(DateUtils.fileTimestamp(from: end)).json"

        do {
            try await githubService.pushFile(
                owner: githubOwner, repo: githubRepo, token: githubToken,
                path: filePath, content: jsonData, commitMessage: "health sync \(DateUtils.fileTimestamp(from: end))"
            )
        } catch { handleFailure(error.localizedDescription); return false }

        let totalRecords = countRecords(payload)
        saveLastSyncDate(end)
        appendSyncHistory(.init(success: true, recordCount: totalRecords, fileSize: jsonData.count, filePath: filePath))
        syncState = .success(recordCount: totalRecords, fileSize: DateUtils.formatBytes(jsonData.count))
        pendingItems = []
        return true
    }

    var lastSyncDisplayText: String? {
        guard let date = lastSyncDate else { return nil }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天 \(DateUtils.timeOnly.string(from: date))" }
        if cal.isDateInYesterday(date) { return "昨天 \(DateUtils.timeOnly.string(from: date))" }
        return DateUtils.shortDateTime.string(from: date)
    }

    private func loadPendingItems() async {
        let start = lastSyncDate ?? Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let end = Date.now
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let msUnit = HKUnit.secondUnit(with: .milli)

        var items: [PendingDataItem] = []

        async let hr = countSamples { try await self.healthService.fetchHeartRate(start: start, end: end).count }
        async let rhr = countSamples { try await self.healthService.fetchQuantitySamples(typeIdentifier: .restingHeartRate, unit: bpmUnit, start: start, end: end).count }
        async let hrv = countSamples { try await self.healthService.fetchQuantitySamples(typeIdentifier: .heartRateVariabilitySDNN, unit: msUnit, start: start, end: end).count }
        async let steps = countSamples { try await self.healthService.fetchQuantitySamples(typeIdentifier: .stepCount, unit: .count(), start: start, end: end).count }
        async let sleep = countSamples {
            let s = try await self.healthService.fetchSleep(start: start, end: end)
            return Set(s.map { DateUtils.dateOnly.string(from: $0.startDate) }).count
        }
        async let workouts = countSamples { try await self.healthService.fetchWorkouts(start: start, end: end).count }

        let c = await (hr, rhr, hrv, steps, sleep, workouts)
        if c.0 > 0 { items.append(.init(icon: "heart.fill", label: "心率采样", count: c.0, unit: "条")) }
        if c.1 > 0 { items.append(.init(icon: "heart.text.clipboard", label: "静息心率", count: c.1, unit: "条")) }
        if c.2 > 0 { items.append(.init(icon: "waveform.path.ecg", label: "HRV", count: c.2, unit: "条")) }
        if c.3 > 0 { items.append(.init(icon: "figure.walk", label: "步数", count: c.3, unit: "条")) }
        if c.4 > 0 { items.append(.init(icon: "bed.double.fill", label: "睡眠", count: c.4, unit: "晚")) }
        if c.5 > 0 { items.append(.init(icon: "figure.run", label: "运动", count: c.5, unit: "次")) }

        pendingItems = items
    }

    private func countSamples(_ block: @Sendable () async throws -> Int) async -> Int {
        (try? await block()) ?? 0
    }

    private func buildSyncPayload(start: Date, end: Date) async throws -> SyncPayload {
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let msUnit = HKUnit.secondUnit(with: .milli)
        let vo2Unit = HKUnit.literUnit(with: .milli).unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute()))

        async let heartRateRaw = healthService.fetchHeartRate(start: start, end: end)
        async let restingHR = healthService.fetchQuantitySamples(typeIdentifier: .restingHeartRate, unit: bpmUnit, start: start, end: end)
        async let hrv = healthService.fetchQuantitySamples(typeIdentifier: .heartRateVariabilitySDNN, unit: msUnit, start: start, end: end)
        async let steps = healthService.fetchQuantitySamples(typeIdentifier: .stepCount, unit: .count(), start: start, end: end)
        async let activeCal = healthService.fetchQuantitySamples(typeIdentifier: .activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)
        async let basalCal = healthService.fetchQuantitySamples(typeIdentifier: .basalEnergyBurned, unit: .kilocalorie(), start: start, end: end)
        async let distance = healthService.fetchQuantitySamples(typeIdentifier: .distanceWalkingRunning, unit: .meterUnit(with: .kilo), start: start, end: end)
        async let standTime = healthService.fetchQuantitySamples(typeIdentifier: .appleStandTime, unit: .minute(), start: start, end: end)
        async let exerciseTime = healthService.fetchQuantitySamples(typeIdentifier: .appleExerciseTime, unit: .minute(), start: start, end: end)
        async let weight = healthService.fetchQuantitySamples(typeIdentifier: .bodyMass, unit: .gramUnit(with: .kilo), start: start, end: end)
        async let bodyFat = healthService.fetchQuantitySamples(typeIdentifier: .bodyFatPercentage, unit: .percent(), start: start, end: end)
        async let vo2Max = healthService.fetchQuantitySamples(typeIdentifier: .vo2Max, unit: vo2Unit, start: start, end: end)
        async let walkingHR = healthService.fetchQuantitySamples(typeIdentifier: .walkingHeartRateAverage, unit: bpmUnit, start: start, end: end)
        async let sleep = healthService.fetchSleep(start: start, end: end)
        async let workouts = healthService.fetchWorkouts(start: start, end: end)

        let df = DateUtils.dateOnly
        let tf = DateUtils.timestampFormatter

        return try await SyncPayload(
            sync_time: iso.string(from: .now),
            period: SyncPeriod(from: iso.string(from: start), to: iso.string(from: end)),
            heartrate_detail: heartRateRaw.map { .init(timestamp: tf.string(from: $0.date), bpm: round($0.bpm * 10) / 10) },
            resting_hr: restingHR.map { .init(date: df.string(from: $0.startDate), bpm: round($0.value * 10) / 10) },
            hrv: hrv.map { .init(date: df.string(from: $0.startDate), sdnn_ms: round($0.value * 10000) / 10000) },
            steps_daily: aggregateDaily(steps, df: df) { recs in .init(date: df.string(from: recs[0].startDate), steps: Int(recs.reduce(0) { $0 + $1.value })) },
            active_calories: aggregateDaily(activeCal, df: df) { recs in .init(date: df.string(from: recs[0].startDate), kcal: round(recs.reduce(0) { $0 + $1.value } * 10) / 10) },
            basal_energy: aggregateDaily(basalCal, df: df) { recs in .init(date: df.string(from: recs[0].startDate), kcal: round(recs.reduce(0) { $0 + $1.value } * 10) / 10) },
            distance_daily: aggregateDaily(distance, df: df) { recs in .init(date: df.string(from: recs[0].startDate), km: round(recs.reduce(0) { $0 + $1.value } * 100) / 100) },
            stand_hours: aggregateDaily(standTime, df: df) { recs in .init(date: df.string(from: recs[0].startDate), hours: round(recs.reduce(0) { $0 + $1.value } / 60 * 10) / 10) },
            exercise_minutes: aggregateDaily(exerciseTime, df: df) { recs in .init(date: df.string(from: recs[0].startDate), minutes: round(recs.reduce(0) { $0 + $1.value } * 10) / 10) },
            sleep: buildSleepRecords(sleep),
            workouts: workouts.map { w in .init(
                date: df.string(from: w.startDate), type: w.activityType,
                duration_min: round(w.duration / 60 * 10) / 10,
                calories: round((w.totalEnergyBurned ?? 0) * 10) / 10,
                avg_hr: round((w.avgHeartRate ?? 0) * 10) / 10,
                max_hr: round((w.maxHeartRate ?? 0) * 10) / 10,
                distance_km: round((w.totalDistance ?? 0) / 1000 * 100) / 100
            )},
            vo2max: vo2Max.map { .init(date: df.string(from: $0.startDate), ml_kg_min: round($0.value * 10) / 10) },
            body_mass: weight.map { .init(date: df.string(from: $0.startDate), kg: round($0.value * 10) / 10) },
            body_fat: bodyFat.map { .init(date: df.string(from: $0.startDate), pct: round($0.value * 100 * 10) / 10) },
            walking_hr: walkingHR.map { .init(date: df.string(from: $0.startDate), bpm: round($0.value * 10) / 10) }
        )
    }

    private func buildSleepRecords(_ samples: [SleepSample]) -> [SleepNightlyRecord] {
        let cal = Calendar.current
        var buckets: [String: [SleepSample]] = [:]
        for sample in samples {
            let hour = cal.component(.hour, from: sample.startDate)
            let nightDate = hour < 18
                ? cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: sample.startDate))!
                : cal.startOfDay(for: sample.startDate)
            let key = DateUtils.dateOnly.string(from: nightDate)
            buckets[key, default: []].append(sample)
        }
        return buckets.keys.sorted().map { date in
            let samples = buckets[date]!
            func hours(for stage: SleepStage) -> Double {
                let intervals = samples.filter { $0.stage == stage }.map { (start: $0.startDate, end: $0.endDate) }
                return round(DailySummary.mergedDuration(intervals) / 3600 * 100) / 100
            }
            let inbed = hours(for: .inBed)
            let deep = hours(for: .deep)
            let rem = hours(for: .rem)
            let core = hours(for: .core)
            let awake = hours(for: .awake)
            let asleep = deep + rem + core
            return SleepNightlyRecord(
                date: date, inbed_hrs: inbed > 0 ? inbed : asleep + awake,
                asleep_hrs: asleep, deep_hrs: deep, rem_hrs: rem, core_hrs: core, awake_hrs: awake
            )
        }
    }

    private func aggregateDaily<T>(_ samples: [QuantitySample], df: DateFormatter, transform: ([QuantitySample]) -> T) -> [T] {
        var grouped: [String: [QuantitySample]] = [:]
        for s in samples { grouped[df.string(from: s.startDate), default: []].append(s) }
        return grouped.keys.sorted().map { transform(grouped[$0]!) }
    }

    private func countRecords(_ p: SyncPayload) -> Int {
        p.heartrate_detail.count + p.resting_hr.count + p.hrv.count + p.steps_daily.count +
        p.active_calories.count + p.basal_energy.count + p.distance_daily.count +
        p.stand_hours.count + p.exercise_minutes.count + p.sleep.count + p.workouts.count +
        p.vo2max.count + p.body_mass.count + p.body_fat.count + p.walking_hr.count
    }

    private func handleFailure(_ msg: String) {
        syncState = .failed(msg)
        appendSyncHistory(.init(success: false, errorMessage: msg))
    }

    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "last_sync_date") as? Date
    }

    private func saveLastSyncDate(_ date: Date) {
        lastSyncDate = date
        UserDefaults.standard.set(date, forKey: "last_sync_date")
    }

    private static let historyKey = "sync_history"

    private func loadSyncHistory() {
        guard let data = UserDefaults.standard.data(forKey: Self.historyKey),
              let entries = try? JSONDecoder().decode([SyncHistoryEntry].self, from: data) else { return }
        syncHistory = entries
    }

    private func appendSyncHistory(_ entry: SyncHistoryEntry) {
        syncHistory.insert(entry, at: 0)
        if syncHistory.count > 30 { syncHistory = Array(syncHistory.prefix(30)) }
        if let data = try? JSONEncoder().encode(syncHistory) {
            UserDefaults.standard.set(data, forKey: Self.historyKey)
        }
    }

    func resetSyncDate() {
        lastSyncDate = nil
        UserDefaults.standard.removeObject(forKey: "last_sync_date")
    }
}
