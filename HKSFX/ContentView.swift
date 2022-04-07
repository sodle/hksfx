//
//  ContentView.swift
//  HKSFX
//
//  Created by Scott Odle on 3/19/22.
//

import SwiftUI
import HealthKit

enum ImportStatus {
    case Pending
    case Failed
    case Completed
    case NoSamples
}

class ImportJob: ObservableObject, Identifiable {
    @Published var status: ImportStatus = .Pending
    @Published var sampleCount: Int = 0
    let dataType: HKQuantityTypeIdentifier
    var dataTypeFriendlyName: String {
        return dataType.rawValue.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "", options: .anchored, range: .none)
    }
    
    init(dataType: HKQuantityTypeIdentifier) {
        self.dataType = dataType
    }
    
    private func onComplete(_ success: Bool, anchor: HKQueryAnchor?) {
        if success {
            self.status = .Completed
            if let anchor = anchor {
                HKPoller.setAnchor(anchor, for: self.dataType)
            }
        } else {
            self.status = .Failed
        }
    }
    
    func execute() {
        HKPoller.getSamples(for: dataType) { dataPoints, anchor in
            DispatchQueue.main.sync {
                self.sampleCount = dataPoints.count
            }
            if dataPoints.count > 0 {
                switch dataPoints[0].type {
                case .Gauge:
                    SfxClient.put(gauges: dataPoints) { success in
                        self.onComplete(success, anchor: anchor)
                    }
                case .Counter:
                    SfxClient.put(counters: dataPoints) { success in
                        self.onComplete(success, anchor: anchor)
                    }
                case .CumulativeCounter:
                    SfxClient.put(cumulativeCounters: dataPoints) { success in
                        self.onComplete(success, anchor: anchor)
                    }
                }
            } else {
                DispatchQueue.main.sync {
                    self.status = .NoSamples
                }
            }
        }
    }
}

struct DataPointView: View {
    let dataPoint: SfxDataPoint
    
    var body: some View {
        HStack {
            switch dataPoint.type {
            case .Gauge:
                Image(systemName: "gauge")
            case .Counter:
                Image(systemName: "number.circle")
            case .CumulativeCounter:
                Image(systemName: "chart.line.uptrend.xyaxis.circle")
            }
            VStack {
                Text(dataPoint.metricName)
                Text(dataPoint.timestamp.ISO8601Format())
            }
            .padding()
            .frame(maxWidth: .infinity)
            Text(String(dataPoint.value.rounded()))
        }
    }
}

struct ImportJobView: View {
    @StateObject var importJob: ImportJob
    
    var body: some View {
        HStack {
            switch importJob.status {
            case .Completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .Pending:
                Image(systemName: "circle")
                    .foregroundColor(.yellow)
            case .Failed:
                Image(systemName: "x.circle")
                    .foregroundColor(.red)
            case .NoSamples:
                Image(systemName: "circle.fill")
                    .foregroundColor(.gray)
            }
            Text(importJob.dataTypeFriendlyName)
                .frame(maxWidth: .infinity)
            Text("\(importJob.sampleCount) samples")
        }
        .padding()
    }
}

struct SfxCredentialsView: View {
    @State var realm: String = SfxClient.getRealm()
    @State var token: String = SfxClient.getToken()
    @State var saved: Bool = true
    
    func save() {
        SfxClient.setRealm(realm)
        SfxClient.setToken(token)
        saved = true
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("SignalFX Realm:")
                TextField("SignalFX Realm", text: $realm)
                    .onChange(of: realm) { _ in
                        saved = false
                    }
            }
            HStack {
                Text("SignalFX Token:")
                TextField("SignalFX Token", text: $token)
                    .onChange(of: token) { _ in
                        saved = false
                    }
            }
            Button(action: save) {
                Text("Save")
            }.disabled(saved)
        }.padding()
    }
}

struct ContentView: View {
    @State var dataPoints: [SfxDataPoint] = []
    @State var importJobs: [ImportJob] = []
    
    func getDataPoints() {
        dataPoints = []
        importJobs = []
        hkRequestPermissions { _, _ in
            hkDataTypes.forEach { type in
                let job = ImportJob(dataType: type)
                importJobs.append(job)
                job.execute()
            }
        }
    }
    
    var body: some View {
        VStack {
            SfxCredentialsView()
            List {
                ForEach(importJobs) {importJob in
                    ImportJobView(importJob: importJob)
                }
            }
            Button(action: getDataPoints) {
                Text("Get Data Points")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            dataPoints: [
                SfxDataPoint(
                    id: UUID(),
                    type: .Gauge,
                    metricName: "hk_heart_rate",
                    value: 60,
                    dimensions: [:],
                    timestamp: Date()
                )
            ],
            importJobs: [
                ImportJob(dataType: .stepCount)
            ]
        )
    }
}
