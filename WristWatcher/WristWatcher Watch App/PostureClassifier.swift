//
//  PostureClassifier.swift
//  WristWatcher Watch App
//
//  D5: the real Core ML model (CoreMLPostureClassifier.swift) implements
//  this protocol. Unchanged from D3 — see docs/DECISIONS.md.
//

protocol PostureClassifier {
    /// Probability the window is non-neutral posture, in [0, 1].
    func classify(_ features: [Double]) -> Double
}

/// SessionEngine's fallback when the bundled Core ML model can't load — a
/// missing/broken model is a packaging problem, not something to crash on at
/// launch. Always returns 0 (neutral), so a broken build never fires a
/// haptic on a classification it isn't actually making.
struct NullClassifier: PostureClassifier {
    func classify(_ features: [Double]) -> Double { 0 }
}
