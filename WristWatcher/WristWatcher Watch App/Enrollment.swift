//
//  Enrollment.swift
//  WristWatcher Watch App
//
//  D5: the model is fitted on gravity channels with a per-donning offset
//  removed (docs/FEATURE-CONTRACT.md §5). This computes that offset — the
//  "anchor" — from a 10 s neutral-wrist hold at the start of every session,
//  discarding the first and last 2 s as guard margin (thesis
//  ship_logreg_binary_meta.json's anchor_calibration_spec).
//
//  Runs on MotionSampler's background queue via ingest() — same O(1),
//  no-allocation discipline as the rest of the hot path: three preallocated
//  arrays, index-written, no growth. The mean/discard math in finish() runs
//  once, off the hot path, same as FeatureExtractor.
//

import Foundation

struct GravityAnchor {
    let x, y, z: Double
}

final class Enrollment {
    enum Result {
        case anchor(GravityAnchor)
        case failed(String)
    }

    /// 10 s hold; the middle 6 s (discarding 2 s at each end) is what's
    /// averaged. See anchor_calibration_spec.fitted_from.
    private static let holdDuration = 10.0
    private static let guardMargin = 2.0

    /// 20 s of margin at 100 Hz — generous headroom over the 10 s hold since
    /// 100 Hz is a ceiling, not a guarantee (PLATFORM-FACTS.md).
    private static let capacity = 2000

    private var timestamps = [Double](repeating: 0, count: capacity)
    private var gravX = [Double](repeating: 0, count: capacity)
    private var gravY = [Double](repeating: 0, count: capacity)
    private var gravZ = [Double](repeating: 0, count: capacity)
    private var count = 0
    private var t0: Double?
    private var finished = false

    var onComplete: ((Result) -> Void)?

    /// Resets state and starts a fresh hold. Call once per enrollment
    /// attempt (not reused across a cancel + retry).
    func start() {
        count = 0
        t0 = nil
        finished = false
    }

    /// Feed one raw sample. Runs on the motion queue — see file header.
    func ingest(_ sample: MotionSample) {
        guard !finished else { return }

        let t0 = self.t0 ?? {
            self.t0 = sample.timestamp
            return sample.timestamp
        }()

        if count < Self.capacity {
            timestamps[count] = sample.timestamp
            gravX[count] = sample.gravity.x
            gravY[count] = sample.gravity.y
            gravZ[count] = sample.gravity.z
            count += 1
        }

        if sample.timestamp - t0 >= Self.holdDuration {
            finish()
        }
    }

    /// User-cancelled hold. Fires .failed once, then ignores further calls.
    func cancel() {
        guard !finished else { return }
        finished = true
        onComplete?(.failed("Enrollment cancelled."))
    }

    private func finish() {
        guard !finished else { return }
        finished = true

        guard let t0 else {
            onComplete?(.failed("No motion samples were captured."))
            return
        }

        var sumX = 0.0, sumY = 0.0, sumZ = 0.0
        var retained = 0
        for i in 0..<count {
            let elapsed = timestamps[i] - t0
            guard elapsed >= Self.guardMargin, elapsed < Self.holdDuration - Self.guardMargin else { continue }
            sumX += gravX[i]
            sumY += gravY[i]
            sumZ += gravZ[i]
            retained += 1
        }

        guard retained > 0 else {
            onComplete?(.failed("Too few motion samples during the hold."))
            return
        }

        let anchor = GravityAnchor(
            x: sumX / Double(retained),
            y: sumY / Double(retained),
            z: sumZ / Double(retained)
        )

        guard anchor.x.isFinite, anchor.y.isFinite, anchor.z.isFinite else {
            onComplete?(.failed("Enrollment produced a non-finite anchor."))
            return
        }

        onComplete?(.anchor(anchor))
    }
}
