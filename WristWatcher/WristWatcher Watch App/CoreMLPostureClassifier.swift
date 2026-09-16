//
//  CoreMLPostureClassifier.swift
//  WristWatcher Watch App
//
//  D5: the real classifier, behind PostureClassifier (unchanged protocol).
//  Deliberately model-agnostic — which model shipped (logistic regression)
//  is the thesis comparison's outcome, not this type's business.
//
//  Input: 36 separately-named doubleType scalars, not one MLMultiArray — the
//  sklearn converter exposes each feature as its own named input
//  (FEATURE-CONTRACT.md §4.1's names and order, exactly).
//
//  Output: `label` (stringType) and `classProbability`
//  (dictionaryType, string-keyed). Classes sort alphabetically to
//  ["neutral", "non-neutral"]; classify() returns classProbability
//  ["non-neutral"].
//
//  computeUnits = .all — the shipping default (thesis deployment-path.md
//  trap #4): classic non-neural model type, the Neural Engine isn't
//  expected to participate.
//
//  Call classify() off the main actor (SessionEngine already does — trap #2:
//  sustained main-thread work is the documented HKWorkoutSession
//  cancellation trigger).
//

import CoreML

final class CoreMLPostureClassifier: PostureClassifier {
    private static let nonNeutralLabel = "non-neutral"

    private let model: MLModel

    /// From the loaded model's own metadata — never hard-coded, since which
    /// model shipped is the comparison's outcome (FEATURE-CONTRACT.md /
    /// SessionSummary.modelIdentifier's own load-bearing note).
    let modelIdentifier: String

    /// Fails if the bundled compiled model can't be found or loaded — a
    /// missing model is a build/packaging problem, not something to paper
    /// over with a fallback classifier.
    init?(resourceName: String = "ship_logreg_binary") {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mlmodelc") else {
            return nil
        }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        guard let model = try? MLModel(contentsOf: url, configuration: config) else {
            return nil
        }
        self.model = model

        let metadata = model.modelDescription.metadata
        modelIdentifier = (metadata[.versionString] as? String)
            ?? (metadata[.description] as? String)
            ?? "unknown"
    }

    func classify(_ features: [Double]) -> Double {
        guard let input = try? MLDictionaryFeatureProvider(
            dictionary: Dictionary(
                uniqueKeysWithValues: zip(FeatureExtractor.featureNames, features.map { MLFeatureValue(double: $0) })
            )
        ), let output = try? model.prediction(from: input),
           let distribution = output.featureValue(for: "classProbability")?.dictionaryValue else {
            return 0
        }
        return distribution[Self.nonNeutralLabel]?.doubleValue ?? 0
    }
}
