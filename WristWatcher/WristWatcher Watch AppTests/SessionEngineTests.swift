//
//  SessionEngineTests.swift
//  WristWatcher Watch AppTests
//
//  Iteration 3: the engine has no enrollment. The test host produces no motion
//  samples, so tests feed windows through `recordWindow`, the same call the
//  window callback makes in production. One window = one second.
//

import XCTest
@testable import WristWatcher_Watch_App

final class SessionEngineTests: XCTestCase {
    private func record(_ engine: SessionEngine, _ activity: Activity?, times: Int) {
        for _ in 0..<times { engine.recordWindow(activity) }
    }

    /// Lets a block queued by the system-end callback run on the main queue.
    private func drainMainQueue() {
        let done = expectation(description: "main queue drained")
        DispatchQueue.main.async { done.fulfill() }
        wait(for: [done], timeout: 2)
    }

    func testStateTransitionsAcrossFullLifecycle() {
        let engine = SessionEngine()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNil(engine.lastSummary)

        engine.start()
        XCTAssertEqual(engine.state, .running)

        engine.stop()
        XCTAssertEqual(engine.state, .finished)
        XCTAssertEqual(engine.lastSummary?.endedBySystem, false)
        XCTAssertEqual(engine.lastSummary?.schemaVersion, 2)

        engine.dismissSummary()
        XCTAssertEqual(engine.state, .idle)
    }

    func testSecondsPerActivityAndSegments() throws {
        let engine = SessionEngine()
        engine.start()
        record(engine, .typing, times: 20)
        record(engine, .mouse, times: 10)
        record(engine, .typing, times: 5)
        engine.stop()

        let summary = try XCTUnwrap(engine.lastSummary)
        XCTAssertEqual(summary.seconds(.typing), 25)
        XCTAssertEqual(summary.seconds(.mouse), 10)
        XCTAssertEqual(summary.seconds(.rest), 0)
        XCTAssertEqual(summary.classifiedSeconds, 35)
        // Window 1 fills second 1..2: the first second of the session is unclassified.
        XCTAssertEqual(summary.segments, [
            Segment(start: 1, end: 21, activity: .typing),
            Segment(start: 21, end: 31, activity: .mouse),
            Segment(start: 31, end: 36, activity: .typing),
        ])
    }

    func testUnlabelledWindowAdvancesTimeAndSplitsTheSegment() throws {
        let engine = SessionEngine()
        engine.start()
        record(engine, .typing, times: 2)
        record(engine, nil, times: 1)
        record(engine, .typing, times: 2)
        engine.stop()

        let summary = try XCTUnwrap(engine.lastSummary)
        XCTAssertEqual(summary.seconds(.typing), 4)
        XCTAssertEqual(summary.segments, [
            Segment(start: 1, end: 3, activity: .typing),
            Segment(start: 4, end: 6, activity: .typing),
        ])
    }

    func testWindowsOutsideARunningSessionAreIgnored() {
        let engine = SessionEngine()
        record(engine, .typing, times: 3)
        engine.start()
        engine.stop()
        record(engine, .typing, times: 3)
        XCTAssertEqual(engine.lastSummary?.classifiedSeconds, 0)
    }

    func testSystemEndFinishesOnceAndStopAfterwardsDoesNothing() throws {
        let engine = SessionEngine()
        engine.start()
        record(engine, .rest, times: 4)

        engine.workout.onUnexpectedEnd?()
        engine.workout.onUnexpectedEnd?()  // a second system-end callback must not finish again
        drainMainQueue()
        XCTAssertEqual(engine.state, .finished)
        let first = try XCTUnwrap(engine.lastSummary)
        XCTAssertTrue(first.endedBySystem)
        XCTAssertEqual(first.seconds(.rest), 4)

        engine.stop()  // the user's Stop arrives after the system end
        XCTAssertEqual(engine.lastSummary?.endedAt, first.endedAt)
        XCTAssertEqual(engine.lastSummary?.endedBySystem, true)
    }

    func testStopThenSystemEndKeepsTheStopSummary() throws {
        let engine = SessionEngine()
        engine.start()
        let end = try XCTUnwrap(engine.workout.onUnexpectedEnd)
        engine.stop()
        let first = try XCTUnwrap(engine.lastSummary)

        end()
        drainMainQueue()
        XCTAssertEqual(engine.lastSummary?.endedAt, first.endedAt)
        XCTAssertEqual(engine.lastSummary?.endedBySystem, false)
    }

    func testReplayScriptParsing() throws {
        let replay = try XCTUnwrap(ReplayClassifier(script: "typing*2,mouse,rest*1"))
        let labels = (0..<6).map { _ in replay.classify([]) }
        XCTAssertEqual(labels, [.typing, .typing, .mouse, .rest, .rest, .rest])  // last label repeats

        XCTAssertNil(ReplayClassifier(script: "typing*2,walking"))
        XCTAssertNil(ReplayClassifier(script: "typing*0"))
        XCTAssertNil(ReplayClassifier(script: ""))
    }
}
