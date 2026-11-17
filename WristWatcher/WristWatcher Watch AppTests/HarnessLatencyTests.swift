//
//  HarnessLatencyTests.swift
//  WristWatcher Watch AppTests
//
//  The thesis's watchOS test harness (Chapter 3, Iteration 2): runs each
//  converted model on the same fixed set of feature windows and logs the time
//  taken by each model call. One call per window; p95 ≤ 100 ms is the limit.
//
//  Inputs sit next to this file and are git-ignored (*.mlmodel, *.csv), copied
//  from the thesis repo, never committed (CLAUDE.md "No participant data"):
//    - logreg / svc_rbf / cart / rf / gb .mlmodel  ← thesis study/analysis/out/final-<date>/
//    - harness_windows.csv  ← thesis study/data/derived/final-<date>/, participant column removed
//      columns: set, 36 feature names, then each model's scikit-learn label.
//
//  Run on the physical watch (Simulator timings mean nothing). Output: one
//  `latency,` line per model in the console, raw per-call times attached to
//  the test result. The label comparison is information only; prediction
//  agreement was checked on the Mac (train_final.py).
//

import CoreML
import XCTest

final class HarnessLatencyTests: XCTestCase {
    private static let models = ["logreg", "svc_rbf", "cart", "rf", "gb"]
    private static let warmup = 20

    func testLatencyPerWindow() throws {
        let bundle = Bundle(for: Self.self)
        let csvURL = try XCTUnwrap(bundle.url(forResource: "harness_windows", withExtension: "csv"),
                                   "harness_windows.csv missing from the test bundle")
        let lines = try String(contentsOf: csvURL, encoding: .utf8)
            .split(whereSeparator: \.isNewline).map { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
        let header = lines[0], rows = lines.dropFirst()
        let col = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1, $0) })

        #if targetEnvironment(simulator)
        print("latency,WARNING simulator run — timings are not the watch's")
        #endif
        var u = utsname(); uname(&u)
        let machine = withUnsafeBytes(of: &u.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        print("latency,model,n,p95_ms,mean_ms,p50_ms,max_ms,label_diff_vs_sklearn,device,os")

        var raw = "model,window,ms\n"
        for name in Self.models {
            let model = try MLModel(contentsOf: try compiledURL(name, in: bundle))
            let inputs = Array(model.modelDescription.inputDescriptionsByName.keys)
            let missing = inputs.filter { col[$0] == nil }
            XCTAssert(missing.isEmpty, "\(name): CSV lacks \(missing)")
            let labelCol = try XCTUnwrap(col[name], "CSV lacks \(name) label column")

            // Inputs built before timing — only the model call is timed.
            let providers = try rows.map { r in
                try MLDictionaryFeatureProvider(dictionary: Dictionary(uniqueKeysWithValues: inputs.map {
                    ($0, MLFeatureValue(double: Double(r[col[$0]!])!))
                }))
            }
            for p in providers.prefix(Self.warmup) { _ = try model.prediction(from: p) }

            var ms = [Double](), diff = 0
            ms.reserveCapacity(providers.count)
            for (i, p) in providers.enumerated() {
                let t0 = DispatchTime.now().uptimeNanoseconds
                let out = try model.prediction(from: p)
                let t1 = DispatchTime.now().uptimeNanoseconds
                ms.append(Double(t1 - t0) / 1e6)
                if out.featureValue(for: "label")?.stringValue != rows[rows.startIndex + i][labelCol] { diff += 1 }
                raw += "\(name),\(i),\(ms[i])\n"
            }
            let s = ms.sorted()
            print("latency,\(name),\(s.count),\(f(pct(s, 95))),\(f(s.reduce(0, +) / Double(s.count))),\(f(pct(s, 50))),\(f(s.last!)),\(diff),\(machine),\(os)")
            XCTAssertEqual(ms.count, rows.count, "\(name) did not run on every window")
        }
        let a = XCTAttachment(data: Data(raw.utf8), uniformTypeIdentifier: "public.comma-separated-values-text")
        a.name = "latency_raw.csv"; a.lifetime = .keepAlways
        add(a)
    }

    /// Xcode compiles each .mlmodel in the test target to .mlmodelc at build time
    /// (MLModel.compileModel is unavailable on watchOS).
    private func compiledURL(_ name: String, in bundle: Bundle) throws -> URL {
        try XCTUnwrap(bundle.url(forResource: name, withExtension: "mlmodelc"), "\(name).mlmodel missing from the test folder")
    }

    /// Linear interpolation between closest ranks — numpy.percentile's default.
    private func pct(_ s: [Double], _ q: Double) -> Double {
        let h = Double(s.count - 1) * q / 100, lo = Int(h)
        return lo + 1 < s.count ? s[lo] + (h - Double(lo)) * (s[lo + 1] - s[lo]) : s[lo]
    }

    private func f(_ x: Double) -> String { String(format: "%.3f", x) }
}
