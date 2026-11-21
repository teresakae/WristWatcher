//
//  ContentView.swift
//  WristWatcher
//
//  watcher-ui-design.md §3.1. Read-only (ARCHITECTURE.md §6) — this view has
//  no controls, only what the watch has already sent. One line per row
//  (dominant activity); everything else moved to SessionDetailView. No
//  pull-to-refresh — delivery is push-based, there's nothing to refresh.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var receiver: Receiver
    @Environment(\.modelContext) private var context
    @Query(sort: \StoredSession.startedAt, order: .reverse) private var sessions: [StoredSession]

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "applewatch.watchface",
                        description: Text("Sessions appear here after they finish on your watch.")
                    )
                } else {
                    ForEach(sessions) { session in
                        if let summary = session.summary {
                            NavigationLink(value: summary) {
                                SessionRow(summary: summary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { context.delete(sessions[i]) }
                    }
                }
                if !receiver.latencyFiles.isEmpty {
                    Section("Latency test files") {
                        ForEach(receiver.latencyFiles, id: \.self) { url in
                            ShareLink(item: url) {
                                Label(url.lastPathComponent, systemImage: "square.and.arrow.up")
                            }
                        }
                        .onDelete(perform: receiver.deleteLatencyFiles)
                    }
                }
            }
            .navigationTitle("Sessions")
            .navigationDestination(for: SessionSummary.self) { summary in
                SessionDetailView(summary: summary)
            }
        }
    }
}

/// One row (FR-8): date + duration leading (plus an "Ended by system" tag),
/// dominant activity trailing.
private struct SessionRow: View {
    let summary: SessionSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.startedAt, style: .date) + Text(" ") + Text(summary.startedAt, style: .time)
                Text(SessionSummary.format(seconds: summary.durationSeconds))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if summary.endedBySystem {
                    Text("Ended by system")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Text(summary.dominant?.displayName ?? "No data")
                .foregroundStyle(.secondary)
        }
    }
}

extension SessionSummary: Hashable {
    static func == (lhs: SessionSummary, rhs: SessionSummary) -> Bool { lhs.sessionId == rhs.sessionId }
    func hash(into hasher: inout Hasher) { hasher.combine(sessionId) }
}

#Preview {
    let container = try! ModelContainer(for: StoredSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    ContentView(receiver: Receiver(context: container.mainContext))
        .modelContainer(container)
}
