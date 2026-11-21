//
//  SessionSummary.swift
//  Shared by the watch and iOS targets (membershipExceptions in project.pbxproj).
//
//  Iteration 3: one Codable struct, transferred watch -> phone via
//  `transferUserInfo`. Seconds per activity plus the segment list. No raw
//  channels, no feature vectors (privacy: only totals and segments leave the
//  watch). schemaVersion 2 replaces the posture-era summary; old ones are not
//  migrated (see docs/ITERATION3_PLAN.md section 3).
//
//  `modelIdentifier` is load-bearing: a history record whose model version is
//  unknown can't be compared against another one, and the thesis compares.
//

import Foundation

/// Raw values are the model's class labels. Case order is the tie-break order
/// for `SessionSummary.dominant`.
enum Activity: String, Codable, CaseIterable {
    case typing, mouse, writing, rest

    var displayName: String {
        switch self {
        case .typing: "Typing"
        case .mouse: "Mouse"
        case .writing: "Handwriting"
        case .rest: "Rest"
        }
    }
}

/// A run of consecutive windows with one label. Seconds from session start.
struct Segment: Codable, Equatable {
    let start: Int
    let end: Int
    let activity: Activity
}

struct SessionSummary: Codable, Identifiable {
    var id: String { sessionId }

    var schemaVersion = 2
    let sessionId: String
    let startedAt: Date
    let endedAt: Date
    let endedBySystem: Bool
    /// Keyed by `Activity.rawValue`. One window = one second.
    let secondsByActivity: [String: Int]
    let segments: [Segment]
    let sampleRateHz: Double
    let modelIdentifier: String
    let appVersion: String
    let invalidationReason: String?

    var durationSeconds: Int { max(0, Int(endedAt.timeIntervalSince(startedAt))) }
    var classifiedSeconds: Int { secondsByActivity.values.reduce(0, +) }

    func seconds(_ activity: Activity) -> Int { secondsByActivity[activity.rawValue] ?? 0 }

    /// Share of classified seconds, whole numbers (may add to 99 or 101).
    func percent(_ activity: Activity) -> Int {
        guard classifiedSeconds > 0 else { return 0 }
        return Int((Double(seconds(activity)) * 100 / Double(classifiedSeconds)).rounded())
    }

    /// Most seconds; ties follow `Activity` case order (max(by:) keeps the first).
    var dominant: Activity? {
        classifiedSeconds == 0 ? nil : Activity.allCases.max { seconds($0) < seconds($1) }
    }

    /// Under 60 s: "59 s". From 60 s: "1 min 0 s".
    static func format(seconds: Int) -> String {
        seconds < 60 ? "\(seconds) s" : "\(seconds / 60) min \(seconds % 60) s"
    }
}
