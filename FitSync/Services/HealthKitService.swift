import Foundation
import HealthKit

final class HealthKitService {
    let healthStore = HKHealthStore()

    static let readTypes: Set<HKObjectType> = {
        let quantityTypes: [HKQuantityType] = [
            .init(.heartRate),
            .init(.restingHeartRate),
            .init(.heartRateVariabilitySDNN),
            .init(.vo2Max),
            .init(.walkingHeartRateAverage),
            .init(.stepCount),
            .init(.distanceWalkingRunning),
            .init(.activeEnergyBurned),
            .init(.basalEnergyBurned),
            .init(.appleExerciseTime),
            .init(.appleStandTime),
            .init(.bodyMass),
            .init(.bodyFatPercentage),
        ]
        let categoryTypes: [HKCategoryType] = [
            .init(.sleepAnalysis),
        ]
        var types = Set<HKObjectType>(quantityTypes)
        types.formUnion(categoryTypes)
        types.insert(HKObjectType.workoutType())
        return types
    }()

    func requestAuthorization() async throws {
        try await healthStore.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    func fetchHeartRate(start: Date, end: Date, limit: Int? = nil) async throws -> [HeartRateSample] {
        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: limit ?? HKObjectQueryNoLimit
        )
        let samples = try await descriptor.result(for: healthStore)
        return samples.map { sample in
            HeartRateSample(
                id: sample.uuid,
                date: sample.startDate,
                bpm: sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
            )
        }
    }

    func fetchSleep(start: Date, end: Date) async throws -> [SleepSample] {
        let type = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = try await descriptor.result(for: healthStore)
        return samples
            .filter { $0.sourceRevision.productType?.hasPrefix("Watch") == true }
            .compactMap { sample in
                guard let stage = SleepStage(categoryValue: sample.value) else { return nil }
                return SleepSample(
                    id: sample.uuid,
                    startDate: sample.startDate,
                    endDate: sample.endDate,
                    stage: stage
                )
            }
    }

    func fetchQuantitySamples(
        typeIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date,
        limit: Int? = nil
    ) async throws -> [QuantitySample] {
        let type = HKQuantityType(typeIdentifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: limit ?? HKObjectQueryNoLimit
        )
        let samples = try await descriptor.result(for: healthStore)
        return samples.map { sample in
            QuantitySample(
                id: sample.uuid,
                startDate: sample.startDate,
                endDate: sample.endDate,
                value: sample.quantity.doubleValue(for: unit),
                unit: unit.unitString
            )
        }
    }

    func fetchCumulativeSum(
        typeIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> Double? {
        let type = HKQuantityType(typeIdentifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )
        let result = try await descriptor.result(for: healthStore)
        return result?.sumQuantity()?.doubleValue(for: unit)
    }

    func fetchLatestQuantity(
        typeIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> Double? {
        let type = HKQuantityType(typeIdentifier)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        let samples = try await descriptor.result(for: healthStore)
        return samples.first?.quantity.doubleValue(for: unit)
    }

    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = try await descriptor.result(for: healthStore)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        return samples.map { workout in
            let hrStats = workout.statistics(for: HKQuantityType(.heartRate))
            return WorkoutSample(
                id: workout.uuid,
                startDate: workout.startDate,
                endDate: workout.endDate,
                activityType: WorkoutSample.activityName(for: workout.workoutActivityType),
                duration: workout.duration,
                totalEnergyBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                totalDistance: workout.totalDistance?.doubleValue(for: .meter()),
                avgHeartRate: hrStats?.averageQuantity()?.doubleValue(for: bpmUnit),
                maxHeartRate: hrStats?.maximumQuantity()?.doubleValue(for: bpmUnit)
            )
        }
    }
}
