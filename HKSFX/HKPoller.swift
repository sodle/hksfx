//
//  HKPoller.swift
//  HKSFX
//
//  Created by Scott Odle on 3/27/22.
//

import Foundation
import HealthKit

extension HKQuantitySample {
    func toSfxDataPoint() -> SfxDataPoint? {
        switch HKQuantityTypeIdentifier(rawValue: self.quantityType.identifier) {
        case .heartRate:
            return SfxDataPoint(
                id: self.uuid,
                type: .Gauge,
                metricName: "hkit_heart_rate",
                value: self.quantity.doubleValue(for: .count().unitDivided(by: .minute())),
                dimensions: [
                    "sf_hires": "1"
                ],
                timestamp: self.endDate
            )
        case .restingHeartRate:
            return SfxDataPoint(
                id: self.uuid,
                type: .Gauge,
                metricName: "hkit_resting_heart_rate",
                value: self.quantity.doubleValue(for: .count().unitDivided(by: .minute())),
                dimensions: [
                    "sf_hires": "1"
                ],
                timestamp: self.endDate
            )
        case .activeEnergyBurned:
            return SfxDataPoint(
                id: self.uuid,
                type: .Counter,
                metricName: "hkit_active_calories_burned",
                value: self.quantity.doubleValue(for: .largeCalorie()),
                dimensions: [
                    "sf_hires": "1"
                ],
                timestamp: self.endDate
            )
        case .appleExerciseTime:
            return SfxDataPoint(
                id: self.uuid,
                type: .Counter,
                metricName: "hkit_exercise_minutes",
                value: self.quantity.doubleValue(for: .minute()),
                dimensions: [
                    "sf_hires": "1"
                ],
                timestamp: self.endDate
            )
        case .appleStandTime:
            return SfxDataPoint(
                id: self.uuid,
                type: .Counter,
                metricName: "hkit_stand_hours",
                value: self.quantity.doubleValue(for: .hour()),
                dimensions: [
                    "sf_hires": "1"
                ],
                timestamp: self.endDate
            )
        case .stepCount:
            return SfxDataPoint(
                id: self.uuid,
                type: .Counter,
                metricName: "hkit_step_count",
                value: self.quantity.doubleValue(for: .count()),
                dimensions: [
                    "sf_hires": "1"
                ],
                timestamp: self.endDate
            )
        default:
            return nil
        }
    }
}

let hkDataTypes: [HKQuantityTypeIdentifier] = [
    .heartRate,
    .restingHeartRate,
    .activeEnergyBurned,
    .appleExerciseTime,
    .appleStandTime,
    .stepCount
]

func hkRequestPermissions(onComplete: @escaping (Bool, Error?) -> Void) {
    let healthStore = HKHealthStore.init()
    healthStore.requestAuthorization(
        toShare: nil,
        read: Set(hkDataTypes.map({ dataType in
            HKQuantityType(dataType)
        })),
        completion: onComplete
    )
}

struct HKPoller {
    static let defaults = UserDefaults.standard
    static let bundleId = Bundle.main.bundleIdentifier ?? "HKSFX"

    static func getSamples(for dataType: HKQuantityTypeIdentifier, onDataPoints: @escaping ([SfxDataPoint], HKQueryAnchor?) -> Void) {
        let healthStore = HKHealthStore.init()
        let query = HKAnchoredObjectQuery(
            type: HKQuantityType(dataType),
            predicate: nil,
            anchor: getAnchor(for: dataType),
            limit: 100000
        ) { query, samples, deletedSamples, anchor, error in
            var dataPoints: [SfxDataPoint] = []
            samples?.forEach({ sample in
                if let sample = sample as? HKQuantitySample {
                    if let dataPoint = sample.toSfxDataPoint() {
                        dataPoints.append(dataPoint)
                    }
                }
            })
            onDataPoints(dataPoints, anchor)
        }
        healthStore.execute(query)
    }
    
    static func anchorKey(for dataType: HKQuantityTypeIdentifier) -> String {
        return "\(bundleId).anchor.\(dataType.rawValue)"
    }
    
    static func getAnchor(for dataType: HKQuantityTypeIdentifier) -> HKQueryAnchor? {
        guard let archivedData = defaults.data(forKey: anchorKey(for: dataType)) else {
            return nil
        }
        do {
            return try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(archivedData) as? HKQueryAnchor
        } catch {
            fatalError("Couldn't deserialize anchor for \(dataType)!")
        }
    }
    
    static func setAnchor(_ anchor: HKQueryAnchor, for dataType: HKQuantityTypeIdentifier) {
        do {
            let archivedData = try NSKeyedArchiver.archivedData(withRootObject: anchor as Any, requiringSecureCoding: true)
            defaults.set(archivedData, forKey: anchorKey(for: dataType))
            defaults.synchronize()
        } catch {
            fatalError("Couldn't serialize anchor for \(anchorKey(for: dataType))!")
        }
    }
}
