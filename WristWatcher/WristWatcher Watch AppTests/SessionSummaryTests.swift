//
//  SessionSummaryTests.swift
//  WristWatcher Watch AppTests
//
//  The summary must survive the encode -> transferUserInfo dict -> decode round
//  trip Transfer/Receiver do, and its derived numbers (percent, dominant,
//  time text) must follow the rules in docs/ITERATION3_PLAN.md section 5.
//

import XCTest
@testable import WristWatcher_Watch_App

final class SessionSummaryTests: XCTestCase {
    private func summary(_ seconds: [String: Int]) -> SessionSummary {
        SessionSummary(
            sessionId: "abc-123",
            startedAt: Date(timeIntervalSince1970: 1000),
            endedAt: Date(timeIntervalSince1970: 1300),
            endedBySystem: false,
            secondsByActivity: seconds,
            segments: [Segment(start: 1, end: 31, activity: .typing)],
            sampleRateHz: 99.7,
            modelIdentifier: "logreg",
            appVersion: "1.0",
            invalidationReason: nil
        )
    }

    func testRoundTripsThroughUserInfoPayload() throws {
        let original = summary(["typing": 30, "rest": 10])
        let userInfo: [String: Any] = ["summary": try JSONEncoder().encode(original)]

        let data = try XCTUnwrap(userInfo["summary"] as? Data)
        let decoded = try JSONDecoder().decode(SessionSummary.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 2)
        XCTAssertEqual(decoded.sessionId, original.sessionId)
        XCTAssertEqual(decoded.secondsByActivity, original.secondsByActivity)
        XCTAssertEqual(decoded.segments, original.segments)
        XCTAssertEqual(decoded.endedBySystem, false)
        XCTAssertNil(decoded.invalidationReason)
    }

    func testPercentAndDominant() {
        let s = summary(["typing": 25, "mouse": 10, "rest": 15])
        XCTAssertEqual(s.classifiedSeconds, 50)
        XCTAssertEqual(s.percent(.typing), 50)
        XCTAssertEqual(s.percent(.mouse), 20)
        XCTAssertEqual(s.percent(.writing), 0)
        XCTAssertEqual(s.dominant, .typing)
    }

    func testDominantTieFollowsTypingMouseWritingRest() {
        XCTAssertEqual(summary(["rest": 5, "mouse": 5]).dominant, .mouse)
        XCTAssertNil(summary([:]).dominant)
        XCTAssertEqual(summary([:]).percent(.typing), 0)
    }

    func testTimeFormatBoundaries() {
        XCTAssertEqual(SessionSummary.format(seconds: 0), "0 s")
        XCTAssertEqual(SessionSummary.format(seconds: 1), "1 s")
        XCTAssertEqual(SessionSummary.format(seconds: 59), "59 s")
        XCTAssertEqual(SessionSummary.format(seconds: 60), "1 min 0 s")
        XCTAssertEqual(SessionSummary.format(seconds: 61), "1 min 1 s")
    }
}
