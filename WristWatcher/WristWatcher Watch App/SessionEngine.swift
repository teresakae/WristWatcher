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
//  UI pass: isRunning replaced by a 3-case state (SummaryView needs a real
//  "finished" state, not just "not running" — that's also true before the
//  first session). Keeps lastSummary for SummaryView to display, and exposes
//  startedAt/blockedReason/transferState for the new views.
//

import CoreMotion
import Foundation
import HealthKit
import Observation

@Observable
final class SessionEngine {
    enum SessionState: Equatable {
        case idle, running, finished
    }

    private(set) var state: SessionState = .idle
    private(set) var windowedSampleCount = 0
    private(set) var lastSummary: SessionSummary?

    private let workout = WorkoutKeepAlive()
    private let sampler: MotionSampler
    private let haptics = HapticController()
    private let transfer = Transfer()
    let classifier = ScriptedClassifier()

    var measuredHz: Double { sampler.measuredHz }
    var transferState: Transfer.TransferState { transfer.state }

    /// Why Start is disabled on IdleView, or nil when nothing blocks it.
    /// Fresh HKHealthStore/CMMotionManager instances, not WorkoutKeepAlive's
    /// or MotionSampler's — both files are off-limits, and these are
    /// capability queries, not instance state, so a second instance reads
    /// the same answer.
    var blockedReason: String? {
        if !CMMotionManager().isDeviceMotionAvailable {
            return "Motion sensors aren't available on this device."
        }
        if HKHealthStore().authorizationStatus(for: HKObjectType.workoutType()) == .sharingDenied {
            return "HealthKit access was denied. Enable it in Settings > Privacy & Security > Health."
        }
        if !transfer.isCompanionAvailable {
            return "No iPhone companion app found. Install WristWatcher on your iPhone."
        }
        return nil
    }

    private(set) var startedAt = Date()
    private(set) var windowsRefused = 0
    private(set) var nonNeutralWindowCount = 0
    private(set) var alertCount = 0
    private var sessionId = UUID().uuidString

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
        guard state != .running else { return }
        sessionId = UUID().uuidString
        startedAt = Date()
        windowedSampleCount = 0
        windowsRefused = 0
        nonNeutralWindowCount = 0
        alertCount = 0
        workout.start()
        sampler.start()
        state = .running
    }

    func stop() {
        guard state == .running else { return }
        sampler.stop()
        workout.stop()

        let summary = SessionSummary(
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
        )
        transfer.send(summary)
        lastSummary = summary
        state = .finished
    }

    /// SummaryView's Done button.
    func dismissSummary() {
        guard state == .finished else { return }
        state = .idle
    }
}
