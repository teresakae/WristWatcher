//
//  StoredSession.swift
//  WristWatcher (iOS only)
//
//  SwiftData record for one received session. The watch sends SessionSummary
//  (Codable, shared by both targets); this stores its JSON as-is plus the two
//  fields the list needs (id for dedupe, date for sorting). Storing the encoded
//  summary instead of one column per field means a schema change in
//  SessionSummary never needs a SwiftData migration.
//

import Foundation
import SwiftData

@Model
final class StoredSession {
    @Attribute(.unique) var sessionId: String
    var startedAt: Date
    /// JSON-encoded SessionSummary.
    var payload: Data

    init(sessionId: String, startedAt: Date, payload: Data) {
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.payload = payload
    }

    var summary: SessionSummary? { try? JSONDecoder().decode(SessionSummary.self, from: payload) }

    /// FR-7: a re-delivered session (same sessionId) replaces the stored one,
    /// never adds a second row. Call on the context's own actor (main).
    static func upsert(_ summary: SessionSummary, in context: ModelContext) throws {
        let payload = try JSONEncoder().encode(summary)
        let id = summary.sessionId
        let existing = try context.fetch(FetchDescriptor<StoredSession>(predicate: #Predicate { $0.sessionId == id }))
        if let row = existing.first {
            row.startedAt = summary.startedAt
            row.payload = payload
        } else {
            context.insert(StoredSession(sessionId: id, startedAt: summary.startedAt, payload: payload))
        }
        try context.save()
    }
}
