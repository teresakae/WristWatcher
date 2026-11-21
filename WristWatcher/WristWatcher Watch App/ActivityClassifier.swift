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

/// Replay mode (Chapter 3, black-box tests). Xcode scheme launch argument:
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
