//
//  SessionEngineTests.swift
//  WristWatcher Watch AppTests
//
//  UI pass: the one new logic this pass introduces — state must not be
//  inferred from "not running", and SummaryView needs lastSummary retained.
//

import XCTest
@testable import WristWatcher_Watch_App

final class SessionEngineTests: XCTestCase {
    func testStateTransitionsAcrossFullLifecycle() {
        let engine = SessionEngine()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertNil(engine.lastSummary)

        engine.start()
        XCTAssertEqual(engine.state, .running)

        engine.stop()
        XCTAssertEqual(engine.state, .finished)
        XCTAssertNotNil(engine.lastSummary)

        engine.dismissSummary()
        XCTAssertEqual(engine.state, .idle)
    }
}
