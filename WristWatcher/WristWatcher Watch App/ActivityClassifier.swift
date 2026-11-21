//
//  ActivityClassifier.swift
//  WristWatcher Watch App
//
//  One window of 36 features in, one activity label out (FR-3). The Core ML
//  model (CoreMLActivityClassifier.swift) is the real implementation;
//  ReplayClassifier is the scripted stand-in for black-box tests.
//

import Foundation

protocol ActivityClassifier: AnyObject {
    /// nil = no usable prediction; the engine leaves that second unclassified.
    func classify(_ features: [Double]) -> Activity?
    /// Recorded in SessionSummary so a history record names its model.
    var modelIdentifier: String { get }
}

/// Replay mode (Chapter 3, black-box tests). Chosen on the watch under
/// Ready > Test mode (`TestPreset`), or by the Xcode launch argument
/// `-replayScript typing*30,mouse*20,rest*10`. One label per window; "rest"
/// alone means one window. When the script runs out the last label repeats.
/// The sensors still run, so windows tick at the normal rate.
final class ReplayClassifier: ActivityClassifier {
    let modelIdentifier = "replay"
    private var labels: [Activity] = []
    private var next = 0

    /// nil if any entry is not `label` or `label*count` with a model label.
    init?(script: String) {
        for entry in script.split(separator: ",") {
            let parts = entry.split(separator: "*", omittingEmptySubsequences: false)
            guard parts.count <= 2,
                  let activity = Activity(rawValue: parts[0].trimmingCharacters(in: .whitespaces)),
                  let count = parts.count == 2 ? Int(parts[1]) : 1,
                  count > 0 else { return nil }
            labels += Array(repeating: activity, count: count)
        }
        if labels.isEmpty { return nil }
    }

    func classify(_ features: [Double]) -> Activity? {
        defer { next += 1 }
        return labels[min(next, labels.count - 1)]
    }
}

/// Test-mode presets for the black-box cases (study/blackbox_checklist.md).
/// Selected id lives in UserDefaults "testPreset"; nil script = real model.
struct TestPreset: Identifiable {
    let id: String
    let name: String
    let script: String?

    static let all: [TestPreset] = [
        TestPreset(id: "real", name: "Real model", script: nil),
        TestPreset(id: "c3", name: "Case 3 · 59 s", script: "typing*59,rest"),
        TestPreset(id: "c4", name: "Case 4 · 60 s", script: "typing*60,rest"),
        TestPreset(id: "c5", name: "Case 5 · 61 s", script: "typing*61,rest"),
        TestPreset(id: "c6", name: "Case 6 · Single", script: "mouse"),
        TestPreset(id: "c7", name: "Case 7 · Mixed", script: "typing*20,mouse*10,writing*15,rest*5,typing*5,rest"),
        TestPreset(id: "c89", name: "Case 8/9 · Typing 20 s", script: "typing*20,rest"),
        TestPreset(id: "size", name: "Size · 600 segments",
                   script: Array(repeating: "typing,mouse", count: 300).joined(separator: ",")),
    ]

    static func named(_ id: String) -> TestPreset { all.first { $0.id == id } ?? all[0] }
}
