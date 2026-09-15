//
//  MotionSampler.swift
//  WristWatcher Watch App
//
//  Adapted from ~/Documents/Personal/WristWatch/WristWatch/WristWatch Watch
//  App/MotionRecorder.swift on 2026-09-15. Stripped to D1 scope: CSV writes,
//  segment stamping, and the audit accumulator are collector-only and not
//  copied. Each sample now feeds a RingBuffer instead of a write buffer.
//
//  CMDeviceMotion @ 100 Hz on a background OperationQueue, never main —
//  sustained CPU on the main queue is a documented cause of
//  HKWorkoutSession cancellation (ARCHITECTURE.md §3).
//

import CoreMotion
import Foundation
import Observation

/// The 9 CMDeviceMotion channels this app has (gyro is unavailable on
/// hardware — see docs/PLATFORM-FACTS.md), plus the sample's real timestamp.
struct MotionSample {
    let timestamp: Double
    let gravity: (x: Double, y: Double, z: Double)
    let userAcceleration: (x: Double, y: Double, z: Double)
    let rotationRate: (x: Double, y: Double, z: Double)
}

@Observable
final class MotionSampler {
    private(set) var isRunning = false
    private(set) var sampleCount = 0
    private(set) var measuredHz: Double = 0

    private let motionManager = CMMotionManager()
    // ponytail: serial queue, not .main — see file header.
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "MotionSampler.motion"
        q.maxConcurrentOperationCount = 1
        return q
    }()

    private let ringBuffer: RingBuffer<MotionSample>

    // Rolling-window rate estimate, same technique as the collector's
    // MotionRecorder: preallocated ring, sort only at the throttled read
    // below, so the per-sample cost stays O(1).
    private var lastTimestamp: Double?
    private var diffRing = [Double](repeating: 0, count: 100)
    private var diffIndex = 0
    private var diffCount = 0

    private var writtenCount = 0
    private var bootEpoch: Double = 0

    init(ringBuffer: RingBuffer<MotionSample>) {
        self.ringBuffer = ringBuffer
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable, !isRunning else { return }

        sampleCount = 0
        measuredHz = 0
        lastTimestamp = nil
        diffIndex = 0
        diffCount = 0
        writtenCount = 0
        bootEpoch = Date().timeIntervalSince1970 - ProcessInfo.processInfo.systemUptime

        motionManager.deviceMotionUpdateInterval = 1.0 / 100.0
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.handle(motion)
        }
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        motionManager.stopDeviceMotionUpdates()
        queue.waitUntilAllOperationsAreFinished()
        isRunning = false
    }

    // Runs on `queue`, never the main queue.
    private func handle(_ motion: CMDeviceMotion) {
        // Sample time, not delivery time — see MotionRecorder's own comment
        // on this; motion.timestamp shares a clock base with systemUptime.
        let ts = bootEpoch + motion.timestamp
        let g = motion.gravity
        let a = motion.userAcceleration
        let r = motion.rotationRate

        ringBuffer.push(MotionSample(
            timestamp: ts,
            gravity: (g.x, g.y, g.z),
            userAcceleration: (a.x, a.y, a.z),
            rotationRate: (r.x, r.y, r.z)
        ))

        if let last = lastTimestamp {
            diffRing[diffIndex % diffRing.count] = ts - last
            diffIndex += 1
            diffCount = min(diffCount + 1, diffRing.count)
        }
        lastTimestamp = ts
        writtenCount += 1

        // One main-queue hop per 10 samples, not per sample — see
        // MotionRecorder's own comment on this budget.
        if writtenCount % 10 == 0 {
            let count = writtenCount
            let hz = diffCount >= 10 ? 1.0 / Self.median(of: Array(diffRing.prefix(diffCount))) : 0
            DispatchQueue.main.async {
                self.sampleCount = count
                if hz > 0 { self.measuredHz = hz }
            }
        }
    }

    private static func median(of values: [Double]) -> Double {
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
