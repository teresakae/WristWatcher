//
//  SessionSummary.swift
//  Shared by the watch and iOS targets — see file header note below.
//
//  D4 scope: one Codable struct, transferred watch -> phone via
//  `transferUserInfo` (ARCHITECTURE.md §6, DECISIONS.md 2026-09-15). No raw
//  channels, no feature vectors — counts and timestamps only.
//
//  `modelIdentifier` is load-bearing: a history record whose model version is
//  unknown can't be compared against another one, and the thesis compares.
//  "scripted-v0" until D5 wires in the real Core ML model's identifier.
//
//  Xcode target membership: this file lives under "WristWatcher Watch App"'s
//  folder-synced group, which defaults it to the watch target only. Open it
//  in Xcode and tick "WristWatcher" in the File Inspector's Target
//  Membership section so it also compiles into the iOS target.
//

import Foundation

struct SessionSummary: Codable, Identifiable {
    var id: String { sessionId }

    let sessionId: String
    let startedAt: Date
    let endedAt: Date
    let sampleRateHz: Double
    let windowCount: Int
    let windowsRefused: Int
    let nonNeutralWindowCount: Int
    let alertCount: Int
    let modelIdentifier: String
    let appVersion: String
    let invalidationReason: String?
}
