//
//  SessionSummaryTests.swift
//  WristWatcher Watch AppTests
//
//  D4: the only logic worth a check here is that a summary survives the
//  encode -> transferUserInfo dict -> decode round trip Transfer/Receiver do.
//

import XCTest
@testable import WristWatcher_Watch_App

final class SessionSummaryTests: XCTestCase {
    func testRoundTripsThroughUserInfoPayload() throws {
        let summary = SessionSummary(
            sessionId: "abc-123",
            startedAt: Date(timeIntervalSince1970: 1000),
            endedAt: Date(timeIntervalSince1970: 1300),
            sampleRateHz: 99.7,
            windowCount: 42,
            windowsRefused: 1,
            nonNeutralWindowCount: 6,
            alertCount: 2,
            modelIdentifier: "scripted-v0",
            appVersion: "1.0",
            invalidationReason: nil
        )

        let encoded = try JSONEncoder().encode(summary)
        let userInfo: [String: Any] = ["summary": encoded]

        let data = try XCTUnwrap(userInfo["summary"] as? Data)
        let decoded = try JSONDecoder().decode(SessionSummary.self, from: data)

        XCTAssertEqual(decoded.sessionId, summary.sessionId)
        XCTAssertEqual(decoded.windowCount, summary.windowCount)
        XCTAssertEqual(decoded.alertCount, summary.alertCount)
        XCTAssertEqual(decoded.modelIdentifier, summary.modelIdentifier)
        XCTAssertNil(decoded.invalidationReason)
    }
}
