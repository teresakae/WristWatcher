//
//  Receiver.swift
//  WristWatcher
//
//  D4: WCSessionDelegate for the read-only companion (ARCHITECTURE.md §6) —
//  displays session history, never commands the watch. Persists to
//  UserDefaults: this is a small, append-only list of summaries, not a data
//  store worth SwiftData for (out of scope, see CLAUDE.md's D0 scope list).
//

import Foundation
import Observation
import WatchConnectivity

@Observable
final class Receiver: NSObject {
    private(set) var summaries: [SessionSummary] = []
    /// Latency-harness CSVs received from the watch, saved in Documents.
    private(set) var latencyFiles: [URL] = []

    private let defaults = UserDefaults.standard
    private let storageKey = "receiver.summaries"

    override init() {
        super.init()
        summaries = Self.load(defaults, key: storageKey)
        latencyFiles = Self.savedLatencyFiles()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    private func add(_ summary: SessionSummary) {
        summaries.removeAll { $0.sessionId == summary.sessionId }
        summaries.insert(summary, at: 0)
        if let data = try? JSONEncoder().encode(summaries) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private static var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    private static func savedLatencyFiles() -> [URL] {
        let all = (try? FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)) ?? []
        return all.filter { $0.lastPathComponent.hasPrefix("latency_raw_") }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func load(_ defaults: UserDefaults, key: String) -> [SessionSummary] {
        guard let data = defaults.data(forKey: key),
              let summaries = try? JSONDecoder().decode([SessionSummary].self, from: data) else { return [] }
        return summaries
    }
}

extension Receiver: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["summary"] as? Data,
              let summary = try? JSONDecoder().decode(SessionSummary.self, from: data) else { return }
        DispatchQueue.main.async { self.add(summary) }
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
