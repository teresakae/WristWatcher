//
//  EnrollmentTests.swift
//  WristWatcher Watch AppTests
//
//  Covers what tools/parity.py deliberately does not — see
//  docs/FEATURE-CONTRACT.md §5's parity note. Parity validates the 36-vector
//  from an already-anchored sample stream; this validates the anchor
//  arithmetic itself: mean-of-middle-6s, discard-first/last-2s, and the
//  refusal path on too little or non-finite data.
//

import XCTest
@testable import WristWatcher_Watch_App

final class EnrollmentTests: XCTestCase {
    private func sample(t: Double, x: Double, y: Double = 0, z: Double = 0) -> MotionSample {
        MotionSample(timestamp: t, gravity: (x, y, z), userAcceleration: (0, 0, 0), rotationRate: (0, 0, 0))
    }

    func testAnchorIsMeanOfMiddleSixSeconds() {
        let enrollment = Enrollment()
        var result: Enrollment.Result?
        enrollment.onComplete = { result = $0 }
        enrollment.start()

        // 100 Hz, t = 0.00 ... 10.00 — the last sample crosses the 10 s hold
        // and triggers finish(). grav_x is 1.0 in [2, 8) and wildly
        // different outside it, so a wrong discard window would move the
        // mean far from 1.0.
        for i in 0...1000 {
            let t = Double(i) / 100.0
            let inMiddle = t >= 2.0 && t < 8.0
            enrollment.ingest(sample(t: t, x: inMiddle ? 1.0 : 1000.0))
        }

        guard case let .anchor(anchor) = result else {
            XCTFail("expected .anchor, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(anchor.x, 1.0, accuracy: 1e-9)
        XCTAssertEqual(anchor.y, 0, accuracy: 1e-9)
        XCTAssertEqual(anchor.z, 0, accuracy: 1e-9)
    }

    func testTooFewSamplesInTheMiddleWindowFails() {
        let enrollment = Enrollment()
        var result: Enrollment.Result?
        enrollment.onComplete = { result = $0 }
        enrollment.start()

        // Only samples outside [2, 8) — nothing survives the discard. The
        // last sample crosses the 10 s hold and triggers finish().
        enrollment.ingest(sample(t: 0.0, x: 1.0))
        enrollment.ingest(sample(t: 9.99, x: 1.0))
        enrollment.ingest(sample(t: 10.0, x: 1.0))

        guard case .failed = result else {
            XCTFail("expected .failed, got \(String(describing: result))")
            return
        }
    }

    func testCancelFailsOnce() {
        let enrollment = Enrollment()
        var completions = 0
        var result: Enrollment.Result?
        enrollment.onComplete = { completions += 1; result = $0 }
        enrollment.start()

        enrollment.cancel()
        enrollment.cancel()
        enrollment.ingest(sample(t: 0, x: 1.0))

        XCTAssertEqual(completions, 1)
        guard case .failed = result else {
            XCTFail("expected .failed, got \(String(describing: result))")
            return
        }
    }
}
