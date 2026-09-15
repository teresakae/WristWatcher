//
//  SessionEngine.swift
//  WristWatcher Watch App
//
//  D3 scope: windows now feed FeatureExtractor, then the (stub, D3) classifier,
//  then HapticController. windowedSampleCount still exists for the on-screen
//  hardware gate check.
//
//  D4: tallies windowsRefused/nonNeutralWindowCount/alertCount alongside it,
//  and pushes a SessionSummary to the phone on stop().
//

import Foundation
import Observation

@Observable
final class SessionEngine {
    private(set) var isRunning = false
    private(set) var windowedSampleCount = 0

    private let workout = WorkoutKeepAlive()
    private let sampler: MotionSampler
    private let haptics = HapticController()
    private let transfer = Transfer()
    let classifier = ScriptedClassifier()

    var measuredHz: Double { sampler.measuredHz }

    private var sessionId = UUID().uuidString
    private var startedAt = Date()
    private var windowsRefused = 0
    private var nonNeutralWindowCount = 0
    private var alertCount = 0

    /// No trained model yet (D5) — see SessionSummary.swift's header.
    private static let modelIdentifier = "scripted-v0"

    init() {
        let ringBuffer = RingBuffer<MotionSample>(
            length: FeatureExtractor.windowLength,
            stride: FeatureExtractor.stride
        )
        sampler = MotionSampler(ringBuffer: ringBuffer)
        ringBuffer.onWindow = { [weak self] window in
            guard let self else { return }
            guard let features = FeatureExtractor.extract(window) else {
                DispatchQueue.main.async { self.windowsRefused += 1 }
                return
            }
            DispatchQueue.main.async {
                self.windowedSampleCount += 1
                let probability = self.classifier.classify(features)
                if probability >= 0.5 { self.nonNeutralWindowCount += 1 }
                if self.haptics.classify(probability: probability) { self.alertCount += 1 }
            }
        }
    }

    func start() {
        guard !isRunning else { return }
        sessionId = UUID().uuidString
        startedAt = Date()
        windowedSampleCount = 0
        windowsRefused = 0
        nonNeutralWindowCount = 0
        alertCount = 0
        workout.start()
        sampler.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        sampler.stop()
        workout.stop()
        isRunning = false

        transfer.send(SessionSummary(
            sessionId: sessionId,
            startedAt: startedAt,
            endedAt: Date(),
            sampleRateHz: sampler.measuredHz,
            windowCount: windowedSampleCount,
            windowsRefused: windowsRefused,
            nonNeutralWindowCount: nonNeutralWindowCount,
            alertCount: alertCount,
            modelIdentifier: Self.modelIdentifier,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            invalidationReason: workout.invalidationReason
        ))
    }
}
