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
//  D5: state gains `.enrolling` — start() no longer goes straight to
//  running. The model needs a per-donning gravity anchor (FEATURE-CONTRACT.md
//  §5); until Enrollment produces one, MotionSampler's sampleFilter returns
//  nil so no un-anchored sample ever reaches the classification window ring.
//  A failed or cancelled enrollment returns to .idle without ever running —
//  refuse loudly, don't classify on a fabricated observation (§6's spirit).
//

import CoreMotion
import Foundation
import HealthKit
import Observation

@Observable
final class SessionEngine {
    enum SessionState: Equatable {
        case idle, enrolling, running, finished
    }

    private(set) var state: SessionState = .idle
    private(set) var windowedSampleCount = 0
    private(set) var lastSummary: SessionSummary?
    /// Set when enrollment fails or is cancelled; shown on IdleView, cleared
    /// on the next start().
    private(set) var enrollmentFailure: String?

    private let workout = WorkoutKeepAlive()
    private let sampler: MotionSampler
    private let haptics = HapticController()
    private let transfer = Transfer()
    private let enrollment = Enrollment()
    let classifier: PostureClassifier

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

    init() {
        // A missing bundled model is a packaging problem the student needs
        // to see, not one to paper over — see EnrollmentView/IdleView's
        // blockedReason for the same "name the cause" philosophy. Falling
        // back to a probability-0 classifier keeps the app usable enough to
        // show that message rather than crashing at launch.
        classifier = CoreMLPostureClassifier() ?? NullClassifier()

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
            // Off the main actor — sustained main-thread work is the
            // documented HKWorkoutSession cancellation trigger.
            let probability = self.classifier.classify(features)
            DispatchQueue.main.async {
                self.windowedSampleCount += 1
                if probability >= 0.5 { self.nonNeutralWindowCount += 1 }
                if self.haptics.classify(probability: probability) { self.alertCount += 1 }
            }
        }
    }

    /// Begins enrollment, not classification — see file header. Wires
    /// `sampler.sampleFilter` to collect the neutral-hold gravity samples
    /// and admits nothing to the window ring until an anchor exists.
    func start() {
        guard state == .idle else { return }
        sessionId = UUID().uuidString
        startedAt = Date()
        windowedSampleCount = 0
        windowsRefused = 0
        nonNeutralWindowCount = 0
        alertCount = 0
        enrollmentFailure = nil

        enrollment.onComplete = { [weak self] result in
            DispatchQueue.main.async { self?.handleEnrollmentResult(result) }
        }
        sampler.sampleFilter = { [weak enrollment] sample in
            enrollment?.ingest(sample)
            return nil
        }
        enrollment.start()

        workout.start()
        sampler.start()
        state = .enrolling
    }

    /// EnrollmentView's Cancel button.
    func cancelEnrollment() {
        guard state == .enrolling else { return }
        enrollment.cancel()
    }

    /// Fires on the main queue (wired in start()) once Enrollment finishes,
    /// successfully or not. A failure or cancellation returns to .idle
    /// without ever admitting a sample to the window ring — no
    /// classification, no haptic, on an uncalibrated session
    /// (FEATURE-CONTRACT.md §6's refusal spirit).
    func handleEnrollmentResult(_ result: Enrollment.Result) {
        guard state == .enrolling else { return }
        switch result {
        case let .anchor(anchor):
            sampler.sampleFilter = { sample in
                MotionSample(
                    timestamp: sample.timestamp,
                    gravity: (
                        sample.gravity.x - anchor.x,
                        sample.gravity.y - anchor.y,
                        sample.gravity.z - anchor.z
                    ),
                    userAcceleration: sample.userAcceleration,
                    rotationRate: sample.rotationRate
                )
            }
            state = .running
        case let .failed(reason):
            sampler.stop()
            workout.stop()
            enrollmentFailure = reason
            state = .idle
        }
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
            modelIdentifier: (classifier as? CoreMLPostureClassifier)?.modelIdentifier ?? "unknown",
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
