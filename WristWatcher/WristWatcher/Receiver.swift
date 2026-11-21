//
//  Receiver.swift
//  WristWatcher
//
//  WCSessionDelegate for the read-only companion (ARCHITECTURE.md §6) —
//  receives session summaries, never commands the watch. Summaries are stored
//  in SwiftData (StoredSession); this class decodes on the WCSession queue and
//  inserts on the main actor, where the model context lives.
//

import Foundation
import Observation
import SwiftData
import WatchConnectivity

@Observable
final class Receiver: NSObject {
    /// Latency-harness CSVs received from the watch, saved in Documents.
    private(set) var latencyFiles: [URL] = []

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        super.init()
        // Posture-era summaries lived in UserDefaults; not migrated.
        UserDefaults.standard.removeObject(forKey: "receiver.summaries")
        latencyFiles = Self.savedLatencyFiles()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func deleteLatencyFiles(at offsets: IndexSet) {
        for i in offsets { try? FileManager.default.removeItem(at: latencyFiles[i]) }
        latencyFiles = Self.savedLatencyFiles()
    }

    private static var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    private static func savedLatencyFiles() -> [URL] {
        let all = (try? FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)) ?? []
        return all.filter { $0.lastPathComponent.hasPrefix("latency_raw_") }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

extension Receiver: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["summary"] as? Data,
              let summary = try? JSONDecoder().decode(SessionSummary.self, from: data) else { return }
        DispatchQueue.main.async { try? StoredSession.upsert(summary, in: self.context) }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard file.metadata?["kind"] as? String == "latency" else { return }
        // Name carries config + run number; add a timestamp so launches don't overwrite each other.
        let stamp = Int(Date().timeIntervalSince1970)
        let name = file.fileURL.deletingPathExtension().lastPathComponent + "_\(stamp).csv"
        let dest = Self.documents.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)
        guard (try? FileManager.default.moveItem(at: file.fileURL, to: dest)) != nil else { return }
        DispatchQueue.main.async { self.latencyFiles = Self.savedLatencyFiles() }
    }
}
