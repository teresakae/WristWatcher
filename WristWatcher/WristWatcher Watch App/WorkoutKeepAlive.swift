//
//  WorkoutKeepAlive.swift
//  WristWatcher Watch App
//
//  Copied verbatim from ~/Documents/Personal/WristWatch/WristWatch/WristWatch
//  Watch App/WorkoutKeepAlive.swift on 2026-09-15. Do not "improve" — see
//  docs/PLATFORM-FACTS.md and the pasteable D1 prompt.
//
//  HKWorkoutSession + WKBackgroundModes = workout-processing (already set in
//  Info.plist / entitlements — see docs/ARCHITECTURE.md §6) keeps
//  CMDeviceMotion delivering with the wrist down and the screen off.
//
//  Ethics: activityType .other, and the builder is ended without ever
//  calling finishWorkout — no workout record is written to the
//  participant's Health app. This is a consent matter, not a preference.
//

import Foundation
import HealthKit
import Observation

@Observable
final class WorkoutKeepAlive: NSObject {
    private(set) var isActive = false

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var expectedEnd = false

    func start() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()], read: []) { [weak self] ok, _ in
            guard ok else { return }
            DispatchQueue.main.async { self?.beginSession() }
        }
    }

    func stop() {
        guard let session, let builder else { return }
        expectedEnd = true
        session.end()
        builder.endCollection(withEnd: Date()) { _, _ in
            // Deliberately no finishWorkout(completion:) call — that is the
            // save. Ending collection without finishing discards it.
        }
        isActive = false
    }

    private func beginSession() {
        let config = HKWorkoutConfiguration()
        config.activityType = .other

        guard let session = try? HKWorkoutSession(healthStore: healthStore, configuration: config) else { return }
        let builder = session.associatedWorkoutBuilder()
        session.delegate = self
        builder.delegate = self

        self.session = session
        self.builder = builder
        expectedEnd = false

        let now = Date()
        session.startActivity(with: now)
        builder.beginCollection(withStart: now) { _, _ in }
        isActive = true
    }

    private func persistInvalidation(_ reason: String) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("workout_invalidations.log")
        let line = "\(Date().timeIntervalSince1970) \(reason)\n"
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try? data.write(to: url)
            }
        }
    }
}

extension WorkoutKeepAlive: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        if toState == .ended, !expectedEnd {
            persistInvalidation("unexpected end: \(fromState.rawValue) -> \(toState.rawValue)")
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        persistInvalidation("error: \(error.localizedDescription)")
    }
}

extension WorkoutKeepAlive: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {}
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
