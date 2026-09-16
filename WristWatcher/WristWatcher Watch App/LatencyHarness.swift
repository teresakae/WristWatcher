//
//  LatencyHarness.swift
//  WristWatcher Watch App
//
//  D5 part 5 ("measure it"). thesis/research/deployment-path.md §4 describes
//  a harness at thesis/pilot/latency-harness/ as already written and
//  verified — confirmed by directory listing that it doesn't exist on disk.
//  Built here instead, following that doc's §4.3 method (docs/DECISIONS.md,
//  2026-09-16): per model, 20 discarded warm-up iterations then 200 timed
//  ones, mean/SD/p50/p95/max in ms, plus real compiled size in the bundle.
//
//  Model-agnostic: enumerates every compiled .mlmodelc in the bundle rather
//  than naming ship_logreg_binary, even though only one model ships — this
//  app only ever needs one, but nothing here assumes that.
//
//  Runs off the main actor (Task.detached) — same reasoning as
//  CoreMLPostureClassifier / SessionEngine: sustained main-thread work is
//  the documented HKWorkoutSession cancellation trigger, and this harness
//  runs its 200-iteration loop inside a real HKWorkoutSession
//  (WorkoutKeepAlive) so the measurement reflects the app's actual runtime
//  session, not thesis's WKExtendedRuntimeSession wiring, which
//  docs/CLAUDE.md marks dead.
//
//  Not part of the normal app flow — see LatencyHarnessView.swift's header
//  for how to run it.
//

import CoreML
import Foundation

struct LatencyResult {
    let modelName: String
    let compiledSizeBytes: Int64
    let meanMs: Double
    let sdMs: Double
    let p50Ms: Double
    let p95Ms: Double
    let maxMs: Double
}

enum LatencyHarness {
    private static let warmupIterations = 20
    private static let timedIterations = 200

    /// Every compiled model in the app bundle, benchmarked in turn. Runs on
    /// whatever thread it's called from — callers run it off the main actor.
    static func run() -> [LatencyResult] {
        compiledModelURLs().compactMap(benchmark(modelAt:))
    }

    private static func compiledModelURLs() -> [URL] {
        guard let resourceURL = Bundle.main.resourceURL,
              let entries = try? FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil)
        else { return [] }
        return entries.filter { $0.pathExtension == "mlmodelc" }
    }

    private static func benchmark(modelAt url: URL) -> LatencyResult? {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        guard let model = try? MLModel(contentsOf: url, configuration: config),
              let input = syntheticInput(for: model)
        else { return nil }

        for _ in 0..<warmupIterations {
            _ = try? model.prediction(from: input)
        }

        var samplesMs = [Double]()
        samplesMs.reserveCapacity(timedIterations)
        for _ in 0..<timedIterations {
            let start = DispatchTime.now()
            _ = try? model.prediction(from: input)
            let end = DispatchTime.now()
            samplesMs.append(Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
        }

        return LatencyResult(
            modelName: url.deletingPathExtension().lastPathComponent,
            compiledSizeBytes: directorySize(url),
            meanMs: mean(samplesMs),
            sdMs: standardDeviation(samplesMs),
            p50Ms: percentile(samplesMs.sorted(), 50),
            p95Ms: percentile(samplesMs.sorted(), 95),
            maxMs: samplesMs.max() ?? 0
        )
    }

    /// One value per named input, typed and shaped from the model's own
    /// description — this is what keeps the harness model-agnostic across
    /// the sklearn-converter path (36 named doubles) and the kNN builder
    /// path (one MLMultiArray), per deployment-path.md §4.1.
    private static func syntheticInput(for model: MLModel) -> MLDictionaryFeatureProvider? {
        var values = [String: MLFeatureValue]()
        for (name, description) in model.modelDescription.inputDescriptionsByName {
            switch description.type {
            case .double:
                values[name] = MLFeatureValue(double: 0)
            case .int64:
                values[name] = MLFeatureValue(int64: 0)
            case .multiArray:
                guard let constraint = description.multiArrayConstraint,
                      let array = try? MLMultiArray(shape: constraint.shape, dataType: constraint.dataType)
                else { return nil }
                values[name] = MLFeatureValue(multiArray: array)
            default:
                return nil
            }
        }
        return try? MLDictionaryFeatureProvider(dictionary: values)
    }

    private static func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            total += Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return total
    }

    private static func mean(_ x: [Double]) -> Double { x.reduce(0, +) / Double(x.count) }

    private static func standardDeviation(_ x: [Double]) -> Double {
        let m = mean(x)
        let variance = x.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(x.count)
        return variance.squareRoot()
    }

    /// Nearest-rank — this is a diagnostic harness, not FEATURE-CONTRACT.md's
    /// exactness argument, so numpy's linear interpolation isn't needed here.
    private static func percentile(_ sorted: [Double], _ q: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = min(sorted.count - 1, Int((q / 100.0) * Double(sorted.count)))
        return sorted[index]
    }
}
