//
//  CoreMLActivityClassifier.swift
//  WristWatcher Watch App
//
//  The shipped model: logreg.mlmodel (sklearn Pipeline converted by
//  coremltools, scaler inside). Input: 36 separately-named doubles in
//  FEATURE-CONTRACT.md's order. Output: `label`, one of the four Activity
//  raw values.
//
//  computeUnits = .all, the shipping default (classic non-neural model, the
//  Neural Engine isn't expected to participate).
//
//  Call classify() off the main actor (SessionEngine already does: sustained
//  main-thread work is the documented HKWorkoutSession cancellation trigger).
//

import CoreML

final class CoreMLActivityClassifier: ActivityClassifier {
    private let model: MLModel

    /// From the loaded model's own metadata, never hard-coded.
    let modelIdentifier: String

    /// Fails if the bundled compiled model can't be found or loaded: a missing
    /// model is a packaging problem, not something to paper over.
    init?(resourceName: String = "logreg") {
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
            ?? resourceName
    }

    func classify(_ features: [Double]) -> Activity? {
        guard let input = try? MLDictionaryFeatureProvider(
            dictionary: Dictionary(
                uniqueKeysWithValues: zip(FeatureExtractor.featureNames, features.map { MLFeatureValue(double: $0) })
            )
        ), let output = try? model.prediction(from: input),
           let label = output.featureValue(for: "label")?.stringValue else {
            return nil
        }
        return Activity(rawValue: label)
    }
}
