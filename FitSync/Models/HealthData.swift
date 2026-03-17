import Foundation
import HealthKit

struct HeartRateSample: Codable, Identifiable {
    let id: UUID
    let date: Date
    let bpm: Double
}

enum SleepStage: String, Codable, CaseIterable {
    case inBed = "InBed"
    case awake = "Awake"
    case rem = "REM"
    case core = "Core"
    case deep = "Deep"

    init?(categoryValue: Int) {
        switch HKCategoryValueSleepAnalysis(rawValue: categoryValue) {
        case .inBed: self = .inBed
        case .awake: self = .awake
        case .asleepREM: self = .rem
        case .asleepCore: self = .core
        case .asleepDeep: self = .deep
        default: return nil
        }
    }
}

struct SleepSample: Codable, Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let stage: SleepStage

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }
}

struct QuantitySample: Codable, Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let value: Double
    let unit: String
}

struct WorkoutSample: Codable, Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let activityType: String
    let duration: TimeInterval
    let totalEnergyBurned: Double?
    let totalDistance: Double?
    let avgHeartRate: Double?
    let maxHeartRate: Double?

    static func activityName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: "跑步"
        case .walking: "步行"
        case .cycling: "骑行"
        case .swimming: "游泳"
        case .hiking: "徒步"
        case .yoga: "瑜伽"
        case .functionalStrengthTraining: "力量训练"
        case .traditionalStrengthTraining: "传统力量训练"
        case .highIntensityIntervalTraining: "HIIT"
        case .coreTraining: "核心训练"
        case .elliptical: "椭圆机"
        case .rowing: "划船"
        case .stairClimbing: "爬楼梯"
        case .jumpRope: "跳绳"
        case .dance: "舞蹈"
        case .cooldown: "放松"
        case .mixedCardio: "混合有氧"
        case .tableTennis: "乒乓球"
        case .badminton: "羽毛球"
        case .tennis: "网球"
        case .basketball: "篮球"
        case .soccer: "足球"
        default: "其他运动"
        }
    }
}

struct DailySummary {
    let date: Date
    var steps: Double?
    var activeEnergy: Double?
    var restingEnergy: Double?
    var walkingRunningDistance: Double?
    var exerciseMinutes: Double?
    var standMinutes: Double?
    var latestWeight: Double?
    var latestBodyFat: Double?
    var restingHeartRate: Double?
    var hrv: Double?
    var vo2Max: Double?
    var walkingHeartRate: Double?
    var heartRateSamples: [HeartRateSample] = []
    var sleepSamples: [SleepSample] = []
    var workouts: [WorkoutSample] = []

    static func mergedDuration(_ intervals: [(start: Date, end: Date)]) -> TimeInterval {
        guard !intervals.isEmpty else { return 0 }
        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [(start: Date, end: Date)] = [sorted[0]]
        for interval in sorted.dropFirst() {
            if interval.start <= merged.last!.end {
                let lastIdx = merged.count - 1
                merged[lastIdx] = (merged[lastIdx].start, max(merged[lastIdx].end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        return merged.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
    }
}
