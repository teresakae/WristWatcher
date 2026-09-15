//
//  SessionEngine.swift
//  WristWatcher Watch App
//
//  D1 scope: start/stop only. No feature vector, no model, no haptic —
//  windowedSampleCount exists so the D1 hardware gate can confirm windows
//  are actually emitted, nothing consumes them yet.
//

import Foundation
import Observation

@Observable
final class SessionEngine {
    private(set) var isRunning = false
    private(set) var windowedSampleCount = 0

    private let workout = WorkoutKeepAlive()
    private let sampler: MotionSampler

    var measuredHz: Double { sampler.measuredHz }

    init() {
        // ponytail: arbitrary placeholder (1 s window / 50% stride at
        // 100 Hz) — real values are a docs/FEATURE-CONTRACT.md fact, not
        // written yet (D0 shipped no feature code). Nothing consumes the
        // emitted windows in D1, so any valid length/stride proves the
        // mechanism.
        let ringBuffer = RingBuffer<MotionSample>(length: 100, stride: 50)
        sampler = MotionSampler(ringBuffer: ringBuffer)
        ringBuffer.onWindow = { [weak self] _ in
            DispatchQueue.main.async { self?.windowedSampleCount += 1 }
        }
    }

    func start() {
        guard !isRunning else { return }
        windowedSampleCount = 0
        workout.start()
        sampler.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        sampler.stop()
        workout.stop()
        isRunning = false
    }
}
