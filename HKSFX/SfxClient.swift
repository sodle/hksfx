//
//  SfxClient.swift
//  HKSFX
//
//  Created by Scott Odle on 3/19/22.
//

import Foundation
import Alamofire
import KeychainSwift

enum SfxMetricType {
    case Gauge
    case Counter
    case CumulativeCounter
}

struct SfxDataPoint: Encodable, Identifiable {
    var id: UUID
    
    let type: SfxMetricType
    let metricName: String
    let value: Double
    let dimensions: [String: String]
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case metricName = "metric"
        case value = "value"
        case dimensions = "dimensions"
        case timestamp = "timestamp"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metricName, forKey: .metricName)
        try container.encode(value, forKey: .value)
        try container.encode(dimensions, forKey: .dimensions)
        try container.encode(Int(timestamp.timeIntervalSince1970), forKey: .timestamp)
    }
    
    func toDictionary() -> NSDictionary {
        return [
            "metric": metricName,
            "value": value,
            "dimensions": dimensions,
            "timestamp": Int(timestamp.timeIntervalSince1970) * 1000,
        ]
    }
}

struct SfxClient {
    static let defaults = UserDefaults.standard
    static let keychain = KeychainSwift()
    
    static let bundleId = Bundle.main.bundleIdentifier ?? "HKSFX"
    static let realmKey = "\(bundleId).sfx_realm"
    static let tokenKey = "\(bundleId).sfx_token"
    
    static func getRealm() -> String {
        return defaults.string(forKey: realmKey) ?? "us0"
    }
    static func setRealm(_ realm: String) {
        defaults.set(realm, forKey: realmKey)
    }
    
    static func getToken() -> String {
        return keychain.get(tokenKey) ?? ""
    }
    static func setToken(_ token: String) {
        keychain.set(token, forKey: tokenKey)
    }
    
    static private func sendDataPoints(gauges: [SfxDataPoint], counters: [SfxDataPoint], cumulativeCounters: [SfxDataPoint], onComplete: @escaping (Bool) -> Void) {
        let sfxIngestUrl = "https://ingest.\(getRealm()).signalfx.com/v2/datapoint"
        let sfxIngestParameters = [
            "gauge": gauges.map{m in m.toDictionary()},
            "counter": counters.map{m in m.toDictionary()},
            "cumulative_counter": cumulativeCounters.map{m in m.toDictionary()},
        ]
        let sfxIngestHeaders: HTTPHeaders = [
            "Content-Type": "application/json",
            "X-SF-Token": getToken(),
        ]
        AF.request(sfxIngestUrl, method: .post, parameters: sfxIngestParameters, encoding: JSONEncoding.default, headers: sfxIngestHeaders).validate().responseData { response in
            debugPrint(response)
            if let error = response.error {
                onComplete(false)
                debugPrint(error)
            } else {
                onComplete(true)
            }
        }
    }
    
    static func put(gauges: [SfxDataPoint], onComplete: @escaping (Bool) -> Void) {
        sendDataPoints(gauges: gauges, counters: [], cumulativeCounters: [], onComplete: onComplete)
    }
    
    static func put(counters: [SfxDataPoint], onComplete: @escaping (Bool) -> Void) {
        sendDataPoints(gauges: [], counters: counters, cumulativeCounters: [], onComplete: onComplete)
    }
    
    static func put(cumulativeCounters: [SfxDataPoint], onComplete: @escaping (Bool) -> Void) {
        sendDataPoints(gauges: [], counters: [], cumulativeCounters: cumulativeCounters, onComplete: onComplete)
    }
}
