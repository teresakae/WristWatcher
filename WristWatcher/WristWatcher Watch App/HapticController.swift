//
//  HapticController.swift
//  WristWatcher Watch App
//
//  D3 scope: one haptic preset, fired under a debounce + cooldown policy.
//  watchOS has no Core Haptics — no custom waveforms — so there is no graded
//  cue by deviation size or duration to build here. That is a platform limit,
//  not a D3 simplification (docs/DECISIONS.md).
//

import WatchKit

/// Debounce + cooldown constants for the one haptic. See docs/DECISIONS.md
/// "Debounce + cooldown haptic policy" — exact values are a D3 decision, not
/// carried over from anywhere.
struct HapticPolicy {
    var consecutiveWindowsToFire = 5   // ≈5 s at 200/100 windows
    var cooldownSeconds = 30.0
    var probabilityThreshold = 0.5
}

/// Turns a per-window non-neutral probability into a single haptic firing,
/// debounced and cooled down. Not thread-safe — call from one queue only
/// (SessionEngine calls it from main).
final class HapticController {
    private let policy: HapticPolicy
    private let fire: () -> Void
    private let now: () -> Date

    private var consecutiveNonNeutral = 0
    private var lastFired: Date?

    init(policy: HapticPolicy = HapticPolicy(),
         fire: @escaping () -> Void = { WKInterfaceDevice.current().play(.notification) },
         now: @escaping () -> Date = Date.init) {
        self.policy = policy
        self.fire = fire
        self.now = now
    }

    /// Feed one window's non-neutral probability. Returns whether the haptic
    /// fired, for tests.
    @discardableResult
    func classify(probability: Double) -> Bool {
        guard probability >= policy.probabilityThreshold else {
            consecutiveNonNeutral = 0
            return false
        }
        consecutiveNonNeutral += 1
        guard consecutiveNonNeutral >= policy.consecutiveWindowsToFire else { return false }

        let t = now()
        if let last = lastFired, t.timeIntervalSince(last) < policy.cooldownSeconds {
            return false
        }
        lastFired = t
        fire()
        return true
    }
}
