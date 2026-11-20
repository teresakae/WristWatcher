//
//  LatencyHarness.swift
//  WristWatcher Watch App
//
//  The thesis latency harness (same loop as HarnessLatencyTests) runnable from
//  a Release/TestFlight build. gb.mlmodel, logreg.mlmodel and
//  harness_windows.csv sit in this folder, git-ignored (*.mlmodel, *.csv),
//  copied from the thesis repo, never committed. Does not touch
//  HKWorkoutSession or SessionEngine. Simulator timings mean nothing.
//

import CoreML
import SwiftUI
import WatchConnectivity

struct LatencyModelResult {
    let name: String
    let n: Int
    let p95: Double, mean: Double, p50: Double, max: Double
    let labelDiff: Int
}

struct LatencyRun {
    let models: [LatencyModelResult]
    let device: String, os: String, config: String
    let rawCSV: String   // "model,window,ms"
}

enum LatencyHarness {
    private static let names = ["gb", "logreg"]
    private static let warmup = 20

    static func run() async throws -> LatencyRun {
        try await Task.detached(priority: .userInitiated) { try measure() }.value
    }

    private static func measure() throws -> LatencyRun {
        guard let csvURL = Bundle.main.url(forResource: "harness_windows", withExtension: "csv") else { throw err("harness_windows.csv missing from bundle") }
        let lines = try String(contentsOf: csvURL, encoding: .utf8)
            .split(whereSeparator: \.isNewline).map { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
        let rows = Array(lines.dropFirst())
        let col = Dictionary(uniqueKeysWithValues: lines[0].enumerated().map { ($1, $0) })

        var u = utsname(); uname(&u)
        let machine = withUnsafeBytes(of: &u.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        #if DEBUG
        let config = "Debug"
        #else
        let config = "Release"
        #endif

        var raw = "model,window,ms\n", results = [LatencyModelResult]()
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else { throw err("\(name).mlmodelc missing from bundle") }
            let model = try MLModel(contentsOf: url)
            let inputs = Array(model.modelDescription.inputDescriptionsByName.keys)
            if let m = inputs.first(where: { col[$0] == nil }) { throw err("\(name): CSV lacks \(m)") }
            guard let labelCol = col[name] else { throw err("CSV lacks \(name) label column") }

            // Inputs built before timing; only the model call is timed.
            let providers = try rows.map { r in
                try MLDictionaryFeatureProvider(dictionary: Dictionary(uniqueKeysWithValues: inputs.map {
                    ($0, MLFeatureValue(double: Double(r[col[$0]!])!))
                }))
            }
            for p in providers.prefix(warmup) { _ = try model.prediction(from: p) }

            var ms = [Double](), diff = 0
            ms.reserveCapacity(providers.count)
            for (i, p) in providers.enumerated() {
                let t0 = DispatchTime.now().uptimeNanoseconds
                let out = try model.prediction(from: p)
                let t1 = DispatchTime.now().uptimeNanoseconds
                ms.append(Double(t1 - t0) / 1e6)
                if out.featureValue(for: "label")?.stringValue != rows[i][labelCol] { diff += 1 }
                raw += "\(name),\(i),\(ms[i])\n"
            }
            let s = ms.sorted()
            results.append(.init(name: name, n: s.count, p95: pct(s, 95), mean: s.reduce(0, +) / Double(s.count),
                                 p50: pct(s, 50), max: s.last!, labelDiff: diff))
        }
        return LatencyRun(models: results, device: machine,
                          os: ProcessInfo.processInfo.operatingSystemVersionString, config: config, rawCSV: raw)
    }

    /// Linear interpolation between closest ranks, numpy.percentile's default.
    private static func pct(_ s: [Double], _ q: Double) -> Double {
        let h = Double(s.count - 1) * q / 100, lo = Int(h)
        return lo + 1 < s.count ? s[lo] + (h - Double(lo)) * (s[lo + 1] - s[lo]) : s[lo]
    }

    private static func err(_ m: String) -> NSError { NSError(domain: "LatencyHarness", code: 1, userInfo: [NSLocalizedDescriptionKey: m]) }
}

/// Plain results screen. Run count is per launch. After a run the raw per-call
/// CSV goes to the iPhone with WCSession.transferFile (session is already
/// activated by Transfer, created in SessionEngine).
struct LatencyHarnessView: View {
    @State private var run: LatencyRun?
    @State private var error: String?
    @State private var isRunning = false
    @State private var runNumber = 0
    @State private var sentNote: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if isRunning {
                    ProgressView("Running…")
                } else {
                    if let error {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                    if let run {
                        ForEach(run.models, id: \.name) { m in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.name).font(.caption).bold()
                                Text("p95 \(f(m.p95)) ms  mean \(f(m.mean)) ms").font(.caption2)
                                Text("label diff \(m.labelDiff) of \(m.n)").font(.caption2)
                            }
                        }
                        Text("\(run.device)  \(run.os)").font(.caption2).foregroundStyle(.secondary)
                        Text("\(run.config), run \(runNumber)").font(.caption2).foregroundStyle(.secondary)
                        if let sentNote { Text(sentNote).font(.caption2).foregroundStyle(.secondary) }
                    }
                    Button(run == nil ? "Run" : "Run again") { start() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .navigationTitle("Latency test")
    }

    private func start() {
        isRunning = true; error = nil; sentNote = nil
        Task {
            do {
                let r = try await LatencyHarness.run()
                runNumber += 1
                run = r
                sentNote = send(r)
            } catch {
                self.error = error.localizedDescription
            }
            isRunning = false
        }
    }

    private func send(_ r: LatencyRun) -> String {
        let session = WCSession.default
        guard session.activationState == .activated else { return "iPhone link not active; raw CSV not sent" }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("latency_raw_\(r.config)_\(runNumber).csv")
        do { try r.rawCSV.write(to: url, atomically: true, encoding: .utf8) } catch { return "raw CSV not saved" }
        session.transferFile(url, metadata: ["kind": "latency", "device": r.device, "os": r.os, "config": r.config])
        return "Raw CSV queued to iPhone"
    }

    private func f(_ x: Double) -> String { String(format: "%.3f", x) }
}
