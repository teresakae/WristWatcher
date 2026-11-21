//
//  SummaryView.swift
//  WristWatcher Watch App
//
//  watcher-ui-design.md §2.4. Reads engine.lastSummary, set in
//  SessionEngine.finish() — this view is unreachable before the first session
//  because it only renders in SessionEngine.State.finished.
//
//  Per-activity time and percent of classified time (FR-5). Transfer row is
//  honest about transferUserInfo being queued and eventual, not "sent to
//  iPhone" the instant the session ends.
//

import SwiftUI

struct SummaryView: View {
    var engine: SessionEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let summary = engine.lastSummary {
                    if summary.endedBySystem {
                        Text("Ended by system")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    SummaryRow(label: "Duration", value: SessionSummary.format(seconds: summary.durationSeconds))

                    if summary.classifiedSeconds == 0 {
                        Text("No data")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Activity.allCases, id: \.self) { activity in
                            SummaryRow(
                                label: activity.displayName,
                                value: "\(SessionSummary.format(seconds: summary.seconds(activity))) (\(summary.percent(activity))%)"
                            )
                        }
                    }

                    SummaryRow(label: "Transfer", value: transferText)
                    SummaryRow(label: "Measured rate", value: "\(String(format: "%.0f", summary.sampleRateHz)) Hz")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Button("Done") { engine.dismissSummary() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private var transferText: String {
        switch engine.transferState {
        case .queued: return "Waiting to send"
        case .sent: return "Sent to iPhone"
        case .failed: return "Couldn't send"
        }
    }
}

/// One label/value pair, combined into a single VoiceOver utterance.
private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SummaryView(engine: SessionEngine())
}
