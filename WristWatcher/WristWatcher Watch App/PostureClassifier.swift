//
//  PostureClassifier.swift
//  WristWatcher Watch App
//
//  D3 stand-in for the D5 Core ML model (README.md's D3 row: "driven by a
//  stub classifier — no Core ML yet"). ScriptedClassifier ignores the
//  feature vector entirely; the D3 hardware gate scripts `probability`
//  directly (e.g. a debug control in ContentView) to drive HapticController
//  through the N-consecutive-windows and cooldown behavior without a trained
//  model. D5 replaces this type, not HapticController.
//

import Observation

protocol PostureClassifier {
    /// Probability the window is non-neutral posture, in [0, 1].
    func classify(_ features: [Double]) -> Double
}

@Observable
final class ScriptedClassifier: PostureClassifier {
    var probability: Double = 0

    func classify(_ features: [Double]) -> Double { probability }
}
