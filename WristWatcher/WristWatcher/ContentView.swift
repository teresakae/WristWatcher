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
                            row(summary)
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

    private func row(_ summary: SessionSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.startedAt, style: .date) + Text(" ") + Text(summary.startedAt, style: .time)
                Text(durationText(summary))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(fractionText(summary))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func durationText(_ summary: SessionSummary) -> String {
        let seconds = max(0, Int(summary.endedAt.timeIntervalSince(summary.startedAt)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func fractionText(_ summary: SessionSummary) -> String {
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
