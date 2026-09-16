//
//  ContentView.swift
//  WristWatcher
//
//  watcher-ui-design.md §3.1. Read-only (ARCHITECTURE.md §6) — this view has
//  no controls, only what the watch has already sent. One number per row
//  (non-neutral fraction); everything else moved to SessionDetailView. No
//  pull-to-refresh — delivery is push-based, there's nothing to refresh.
//

import SwiftUI

struct ContentView: View {
    var receiver: Receiver

    var body: some View {
        NavigationStack {
            List {
                if receiver.summaries.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "applewatch.watchface",
                        description: Text("Sessions appear here after they finish on your watch.")
                    )
                } else {
                    ForEach(receiver.summaries) { summary in
                        NavigationLink(value: summary) {
                            SessionRow(summary: summary)
                        }
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

/// One row: date + duration leading, non-neutral fraction trailing — the
/// one number a row scanned at arm's length supports (design §3.1).
private struct SessionRow: View {
    let summary: SessionSummary

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.startedAt, style: .date) + Text(" ") + Text(summary.startedAt, style: .time)
                Text(durationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(fractionText)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var durationText: String {
        let seconds = max(0, Int(summary.endedAt.timeIntervalSince(summary.startedAt)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var fractionText: String {
        guard summary.windowCount > 0 else { return "0%" }
        let fraction: Double = Double(summary.nonNeutralWindowCount) / Double(summary.windowCount)
        let pct: Int = Int((fraction * 100).rounded())
        return "\(pct)%"
    }
}

extension SessionSummary: Hashable {
    static func == (lhs: SessionSummary, rhs: SessionSummary) -> Bool { lhs.sessionId == rhs.sessionId }
    func hash(into hasher: inout Hasher) { hasher.combine(sessionId) }
}

#Preview {
    ContentView(receiver: Receiver())
}
