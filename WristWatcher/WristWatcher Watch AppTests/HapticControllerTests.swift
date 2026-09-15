//
//  HapticControllerTests.swift
//  WristWatcher Watch AppTests
//
//  The D3 gate: fires after N consecutive non-neutral windows, not before;
//  does not repeat inside cooldown; fires again after.
//

import XCTest
@testable import WristWatcher_Watch_App

final class HapticControllerTests: XCTestCase {
    func testDoesNotFireBeforeNMinus1Windows() {
        var fireCount = 0
        let controller = HapticController(
            policy: HapticPolicy(consecutiveWindowsToFire: 5, cooldownSeconds: 30, probabilityThreshold: 0.5),
            fire: { fireCount += 1 }
        )

        for _ in 0..<4 {
            XCTAssertFalse(controller.classify(probability: 1.0))
        }
        XCTAssertEqual(fireCount, 0)
    }

    func testFiresOnTheNthWindow() {
        var fireCount = 0
        let controller = HapticController(
            policy: HapticPolicy(consecutiveWindowsToFire: 5, cooldownSeconds: 30, probabilityThreshold: 0.5),
            fire: { fireCount += 1 }
        )

        for _ in 0..<4 { _ = controller.classify(probability: 1.0) }
        XCTAssertTrue(controller.classify(probability: 1.0))
        XCTAssertEqual(fireCount, 1)
    }

    func testBelowThresholdResetsTheDebounceCount() {
        var fireCount = 0
        let controller = HapticController(
            policy: HapticPolicy(consecutiveWindowsToFire: 5, cooldownSeconds: 30, probabilityThreshold: 0.5),
            fire: { fireCount += 1 }
        )

        for _ in 0..<4 { _ = controller.classify(probability: 1.0) }
        _ = controller.classify(probability: 0.0)          // resets the streak
        for _ in 0..<4 { XCTAssertFalse(controller.classify(probability: 1.0)) }
        XCTAssertEqual(fireCount, 0)
    }

    func testDoesNotRefireInsideCooldownButFiresAfter() {
        var fireCount = 0
        var clock = Date(timeIntervalSince1970: 0)
        let controller = HapticController(
            policy: HapticPolicy(consecutiveWindowsToFire: 5, cooldownSeconds: 30, probabilityThreshold: 0.5),
            fire: { fireCount += 1 },
            now: { clock }
        )

        for _ in 0..<5 { _ = controller.classify(probability: 1.0) }
        XCTAssertEqual(fireCount, 1)

        clock = clock.addingTimeInterval(29)
        XCTAssertFalse(controller.classify(probability: 1.0))
        XCTAssertEqual(fireCount, 1)

        clock = clock.addingTimeInterval(2)   // t = 31s, past the 30s cooldown
        XCTAssertTrue(controller.classify(probability: 1.0))
        XCTAssertEqual(fireCount, 2)
    }
}
