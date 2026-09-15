//
//  RingBuffer.swift
//  WristWatcher Watch App
//
//  Emits a fixed-length window every `stride` samples. No feature
//  computation and no real length/stride constants — those belong to
//  docs/FEATURE-CONTRACT.md (not written yet; D0 shipped no feature code,
//  see CLAUDE.md). Generic over the sample type so it's provably correct on
//  arbitrary length/stride ahead of that contract landing.
//
//  push() is O(1) — same ring-index-then-read-at-window-end pattern as the
//  collector's MotionRecorder rate/omega rings (ARCHITECTURE.md §3): no
//  allocation, no shifting, on every 100 Hz sample.
//

import Foundation

final class RingBuffer<Element> {
    private let length: Int
    private let stride: Int
    private var storage: [Element?]
    private var totalCount = 0

    /// Settable after init so a caller can wire a closure that captures
    /// itself once its own initialization has finished.
    var onWindow: (([Element]) -> Void)?

    init(length: Int, stride: Int, onWindow: (([Element]) -> Void)? = nil) {
        precondition(length > 0 && stride > 0)
        self.length = length
        self.stride = stride
        self.storage = [Element?](repeating: nil, count: length)
        self.onWindow = onWindow
    }

    func push(_ sample: Element) {
        storage[totalCount % length] = sample
        totalCount += 1
        if totalCount >= length, (totalCount - length) % stride == 0 {
            onWindow?(windowInOrder())
        }
    }

    /// Oldest-to-newest. Only called on emission, not per sample.
    private func windowInOrder() -> [Element] {
        let start = totalCount % length
        return (0..<length).map { storage[(start + $0) % length]! }
    }
}
