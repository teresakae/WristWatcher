//
//  SessionEngineTests.swift
//  WristWatcher Watch AppTests
//
//  UI pass: the one new logic this pass introduces — state must not be
//  inferred from "not running", and SummaryView needs lastSummary retained.
//
//  D5: start() now goes to .enrolling, not .running — real enrollment needs
//  10 real seconds of motion samples the test host doesn't produce (no
//  physical sensor here), so these tests drive `handleEnrollmentResult`
//  directly, same as production code does from Enrollment's completion
//  callback, rather than waiting out a real hold.
//

import XCTest
@testable import WristWatcher_Watch_App

final class SessionEngineTests: XCTestCase {
    func testStateTransitionsAcrossFullLifecycle() {
        let engine = SessionEngine()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNil(engine.lastSummary)

        engine.start()
        XCTAssertEqual(engine.state, .enrolling)

        engine.handleEnrollmentResult(.anchor(GravityAnchor(x: 0, y: 0, z: 0)))
        XCTAssertEqual(engine.state, .running)

        engine.stop()
        XCTAssertEqual(engine.state, .finished)
        XCTAssertNotNil(engine.lastSummary)

        engine.dismissSummary()
        XCTAssertEqual(engine.state, .idle)
    }

    func testFailedEnrollmentReturnsToIdleWithoutRunning() {
        let engine = SessionEngine()
        engine.start()
        XCTAssertEqual(engine.state, .enrolling)

        engine.handleEnrollmentResult(.failed("Too few motion samples during the hold."))
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.enrollmentFailure, "Too few motion samples during the hold.")
        XCTAssertNil(engine.lastSummary)
    }

    func testStartingClearsAPreviousEnrollmentFailure() {
        let engine = SessionEngine()
        engine.start()
        engine.handleEnrollmentResult(.failed("Too few motion samples during the hold."))
        XCTAssertNotNil(engine.enrollmentFailure)

        engine.start()
        XCTAssertNil(engine.enrollmentFailure)
    }
}
