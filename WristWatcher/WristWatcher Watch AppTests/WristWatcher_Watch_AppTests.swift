import XCTest
@testable import WristWatcher_Watch_App

final class WristWatcher_Watch_AppTests: XCTestCase {
    func testRingBufferEmitsSlidingWindows() {
        var emitted: [[Int]] = []
        let buffer = RingBuffer<Int>(length: 4, stride: 2)
        buffer.onWindow = { emitted.append($0) }

        for sample in 1...8 {
            buffer.push(sample)
        }

        XCTAssertEqual(emitted, [
            [1, 2, 3, 4],
            [3, 4, 5, 6],
            [5, 6, 7, 8],
        ])
    }
}
