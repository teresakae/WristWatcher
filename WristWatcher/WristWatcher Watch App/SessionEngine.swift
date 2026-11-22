//
//  SessionEngine.swift
//  WristWatcher Watch App
//
//  Iteration 3: Start goes straight to running (no enrollment, no gravity
//  anchor: the model was trained on raw gravity). Each 2 s window (100
//  samples apart) is classified once; a window counts as one second, so the
//  first second of a session is unclassified (docs/ITERATION3_PLAN.md
//  section 5). The engine keeps seconds per activity and the segment list,
//  and sends a SessionSummary to the phone when the session finishes.
//
//  A session finishes exactly once: Stop (main queue) and a system-ended
//  workout (HK delegate queue, hopped to main) both go through `finish`,
//  and the first one in wins.
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
    private(set) var lastSummary: SessionSummary?

    let workout = WorkoutKeepAlive()  // not private: tests fire onUnexpectedEnd
    private let sampler: MotionSampler
    private let ringBuffer: RingBuffer<MotionSample>
    private let transfer = Transfer()
    /// Chosen in start(): launch-arg replay, else the Test mode preset, else
    /// the Core ML model. Only reassigned while idle, before samples flow.
    /// A missing Core ML model keeps Start disabled (`blockedReason`).
    private(set) var classifier: ActivityClassifier?
    private let coreML = CoreMLActivityClassifier()

    var measuredHz: Double { sampler.measuredHz }
    var sampleCount: Int { sampler.sampleCount }
    var transferState: Transfer.TransferState { transfer.state }
    var transferError: String? { transfer.lastError }
    func retryTransfer() { transfer.retry() }

    /// Why Start is disabled on IdleView, or nil when nothing blocks it.
    /// Fresh HKHealthStore/CMMotionManager instances: these are capability
    /// queries, not instance state, so a second instance reads the same answer.
    var blockedReason: String? {
        if coreML == nil {
            return "No classifier: the model is missing from the app, or the replay script is invalid."
        }
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
    private var sessionId = UUID().uuidString
    private var windowIndex = 0
    private var secondsByActivity: [String: Int] = [:]
    private var segments: [Segment] = []

    init() {
        classifier = coreML

        ringBuffer = RingBuffer<MotionSample>(
            length: FeatureExtractor.windowLength,
            stride: FeatureExtractor.stride
        )
        sampler = MotionSampler(ringBuffer: ringBuffer)
        ringBuffer.onWindow = { [weak self] window in
            guard let self else { return }
            // Off the main actor: sustained main-thread work is the
            // documented HKWorkoutSession cancellation trigger.
            let activity = FeatureExtractor.extract(window).flatMap { self.classifier?.classify($0) }
            DispatchQueue.main.async { self.recordWindow(activity) }
        }
    }

    func start() {
        guard state == .idle else { return }
        let id = UUID().uuidString
        sessionId = id
        startedAt = Date()
        windowIndex = 0
        secondsByActivity = [:]
        segments = []
        classifier = Self.chooseClassifier(fallback: coreML)
        ringBuffer.reset()

        // Callback comes from the HealthKit delegate queue. The id check keeps
        // a late callback from ending a later session.
        workout.onUnexpectedEnd = { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.sessionId == id else { return }
                self.finish(endedBySystem: true)
            }
        }
        workout.start()
        sampler.start()
        state = .running
    }

    /// Launch argument `-replayScript ...` wins, then the Test mode preset
    /// (UserDefaults "testPreset"), then the real model. An invalid replay
    /// script yields nil, which stops nothing here but classifies nothing.
    static func chooseClassifier(fallback: ActivityClassifier?) -> ActivityClassifier? {
        let defaults = UserDefaults.standard
        if let script = defaults.string(forKey: "replayScript") {
            return ReplayClassifier(script: script)
        }
        if let script = TestPreset.named(defaults.string(forKey: "testPreset") ?? "real").script {
            return ReplayClassifier(script: script)
        }
        return fallback
    }

    /// One window = one second. Window i (1-based, ends 1 s after window
    /// i-1) fills seconds [i, i+1); seconds 0..1 are never classified. A window
    /// with no label (nil) advances time but adds no seconds and ends the
    /// current segment. Internal, not private, so tests can feed a script.
    func recordWindow(_ activity: Activity?) {
        guard state == .running else { return }
        windowIndex += 1
        guard let activity else { return }
        secondsByActivity[activity.rawValue, default: 0] += 1
        if let last = segments.last, last.activity == activity, last.end == windowIndex {
            segments[segments.count - 1] = Segment(start: last.start, end: windowIndex + 1, activity: activity)
        } else {
            segments.append(Segment(start: windowIndex, end: windowIndex + 1, activity: activity))
        }
    }

    func stop() {
        finish(endedBySystem: false)
    }

    /// The one place a session ends. Main queue only; the state check makes
    /// the second of two racing callers (Stop vs system end) a no-op.
    private func finish(endedBySystem: Bool) {
        guard state == .running else { return }
        state = .finished
        sampler.stop()
        workout.stop()

        let summary = SessionSummary(
            sessionId: sessionId,
            startedAt: startedAt,
            endedAt: Date(),
            endedBySystem: endedBySystem,
            secondsByActivity: secondsByActivity,
            segments: segments,
            sampleRateHz: sampler.measuredHz,
            modelIdentifier: classifier?.modelIdentifier ?? "unknown",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            invalidationReason: workout.invalidationReason
        )
        transfer.send(summary)
        lastSummary = summary
    }

    /// SummaryView's Done button.
    func dismissSummary() {
        guard state == .finished else { return }
        state = .idle
    }
}
