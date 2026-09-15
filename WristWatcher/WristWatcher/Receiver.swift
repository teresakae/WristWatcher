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

    private let defaults = UserDefaults.standard
    private let storageKey = "receiver.summaries"

    override init() {
        super.init()
        summaries = Self.load(defaults, key: storageKey)
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
}
