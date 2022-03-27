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

struct SfxDataPoint: Encodable {
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
    static func setRealm(realm: String) {
        defaults.set(realm, forKey: realmKey)
    }
    
    static func getToken() -> String {
        return keychain.get(tokenKey) ?? ""
    }
    static func setToken(token: String) {
        keychain.set(token, forKey: tokenKey)
    }
    
    static func sendDataPoints(gauges: [SfxDataPoint], counters: [SfxDataPoint], cumulativeCounters: [SfxDataPoint]) {
        let sfxIngestUrl = "https://ingest.\(getRealm()).signalfx.com/v2/datapoint"
        let sfxIngestParameters = [
            "gauge": gauges,
            "counter": counters,
            "cumulative_counter": cumulativeCounters,
        ]
        let sfxIngestHeaders: HTTPHeaders = [
            "Content-Type": "application/json",
            "X-SF-Token": getToken(),
        ]
        AF.request(sfxIngestUrl, method: .post, parameters: sfxIngestParameters, headers: sfxIngestHeaders).validate().responseData { response in
            debugPrint(response)
        }
    }
}
