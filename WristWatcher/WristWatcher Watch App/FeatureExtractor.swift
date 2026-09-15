//
//  FeatureExtractor.swift
//  WristWatcher Watch App
//
//  The 36-feature vector of docs/FEATURE-CONTRACT.md. That file is the
//  authority for every constant and every formula here; this file is one of
//  its two implementations, the other being the thesis repo's
//  pilot/analysis/lib/features.py, which the D5 model is fitted on.
//
//  Read FEATURE-CONTRACT.md before changing anything below. A wrong SD
//  denominator, percentile rule, or vector order does not throw, does not log,
//  and does not stop the app — it silently asks the model a different
//  question. FeatureParityTests is what catches that.
//
//  NOT on the 100 Hz hot path. This runs once per RingBuffer emission — every
//  `stride` samples, so 1 Hz at the contract's 200/100 — where 9 sorts of 200
//  Doubles is affordable. The 100 Hz callback stays O(1) (CLAUDE.md).
//

import Foundation

enum FeatureExtractor {
    // MARK: - Contract constants (FEATURE-CONTRACT.md §1)

    /// Samples per window. 2.0 s at 100 Hz.
    static let windowLength = 200
    /// Samples between window emissions. 50% overlap.
    static let stride = 100

    // MARK: - Layout (FEATURE-CONTRACT.md §2, §3, §4)

    /// CSV file order of the collector's DATA-CONTRACT.md §2.1, minus
    /// `timestamp`. Order is normative — not alphabetical, not axis-grouped.
    static let channelNames = [
        "grav_x", "grav_y", "grav_z",
        "uacc_x", "uacc_y", "uacc_z",
        "gyro_x", "gyro_y", "gyro_z",
    ]

    /// `features.DEFAULT_STATS`.
    static let statNames = ["mean", "std", "p25", "p75"]

    /// Stat-major, channel-minor — `features.feature_names`, which is
    /// `[f"{c}_{s}" for s in stats for c in channels]`. The statistic is the
    /// OUTER loop. Channel-blocked is the intuitive order and the wrong one.
    static let featureNames: [String] = statNames.flatMap { stat in
        channelNames.map { "\($0)_\(stat)" }
    }

    static let featureCount = 36  // 9 channels x 4 statistics

    /// Same order as `channelNames`, and that is the only thing keeping the
    /// two aligned — kept adjacent to it for exactly that reason.
    private static let channels: [(MotionSample) -> Double] = [
        { $0.gravity.x }, { $0.gravity.y }, { $0.gravity.z },
        { $0.userAcceleration.x }, { $0.userAcceleration.y }, { $0.userAcceleration.z },
        { $0.rotationRate.x }, { $0.rotationRate.y }, { $0.rotationRate.z },
    ]

    // MARK: - Extraction

    /// 36 raw, unscaled features for one window, or `nil` if any is
    /// non-finite.
    ///
    /// Unscaled is deliberate: the fitted `StandardScaler` ships inside the
    /// `.mlmodel` because the converted object is the whole sklearn Pipeline
    /// (FEATURE-CONTRACT.md §5). Scaling here would scale twice.
    ///
    /// `nil` means drop the window. Never impute — §6.
    static func extract(_ window: [MotionSample]) -> [Double]? {
        precondition(window.count == windowLength,
                     "window must be exactly \(windowLength) samples, got \(window.count)")

        let columns = channels.map { channel in window.map(channel) }
        let means = columns.map(mean)
        let sorted = columns.map { $0.sorted() }

        var out = [Double]()
        out.reserveCapacity(featureCount)
        out += means
        out += zip(columns, means).map { standardDeviation(of: $0, mean: $1) }
        out += sorted.map { percentile($0, 25) }
        out += sorted.map { percentile($0, 75) }

        // Trust boundary, not a debug assert — see §6. A NaN reaching Core ML
        // produces a confident prediction, not an error.
        return out.allSatisfy(\.isFinite) ? out : nil
    }

    // MARK: - Statistics

    private static func mean(_ x: [Double]) -> Double {
        x.reduce(0, +) / Double(x.count)
    }

    /// Population SD, ddof = 0, two-pass — `ndarray.std()`'s default.
    ///
    /// ddof = 1 is wrong by sqrt(n/(n-1)) and the scaler would hide it.
    /// One-pass (`E[x^2] - E[x]^2`) cancels catastrophically on the gravity
    /// channels, where values sit near +/-1 with a small spread. See §3.2.
    private static func standardDeviation(of x: [Double], mean m: Double) -> Double {
        let sumSquares = x.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        return (sumSquares / Double(x.count)).squareRoot()
    }

    /// numpy's `method="linear"` percentile. `sorted` must be ascending.
    /// See §3.3 — including why the interpolation has two branches.
    private static func percentile(_ sorted: [Double], _ q: Double) -> Double {
        let h = Double(sorted.count - 1) * q / 100.0
        let lo = Int(h.rounded(.down))
        guard lo + 1 < sorted.count else { return sorted[sorted.count - 1] }
        let t = h - Double(lo)
        let a = sorted[lo], b = sorted[lo + 1]
        // numpy `_lerp`: from `a` below the midpoint, from `b` at or above it.
        return t < 0.5 ? a + (b - a) * t : b - (b - a) * (1 - t)
    }
}
