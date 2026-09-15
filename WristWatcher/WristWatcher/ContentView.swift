//
//  ContentView.swift
//  WristWatcher
//
//  D4: session history list, read-only (ARCHITECTURE.md §6) — this view has
//  no controls, only what the watch has already sent.
//

import SwiftUI

struct ContentView: View {
    var receiver: Receiver

    var body: some View {
        NavigationStack {
            List {
                if receiver.summaries.isEmpty {
                    Text("No sessions yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(receiver.summaries) { summary in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.startedAt, style: .date) + Text(" ") + Text(summary.startedAt, style: .time)
                        Text("\(summary.alertCount) alerts · \(summary.nonNeutralWindowCount)/\(summary.windowCount) non-neutral windows")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(summary.modelIdentifier) · \(String(format: "%.0f", summary.sampleRateHz)) Hz")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        if let reason = summary.invalidationReason {
                            Text("Invalidated: \(reason)")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Session History")
        }
    }
}

#Preview {
    ContentView(receiver: Receiver())
}
