//
//  SessionEngine.swift
//  WristWatcher Watch App
//
//  D3 scope: windows now feed FeatureExtractor, then the (stub, D3) classifier,
//  then HapticController. windowedSampleCount still exists for the on-screen
//  hardware gate check.
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
    let classifier = ScriptedClassifier()

    var measuredHz: Double { sampler.measuredHz }

    init() {
        let ringBuffer = RingBuffer<MotionSample>(
            length: FeatureExtractor.windowLength,
            stride: FeatureExtractor.stride
        )
        sampler = MotionSampler(ringBuffer: ringBuffer)
        ringBuffer.onWindow = { [weak self] window in
            guard let features = FeatureExtractor.extract(window) else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                self.windowedSampleCount += 1
                let probability = self.classifier.classify(features)
                self.haptics.classify(probability: probability)
            }
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
