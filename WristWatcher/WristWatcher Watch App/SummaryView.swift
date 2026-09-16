//
//  SummaryView.swift
//  WristWatcher Watch App
//
//  watcher-ui-design.md §2.4. Reads engine.lastSummary, set in
//  SessionEngine.stop() — this view is unreachable before the first session
//  because it only renders in SessionEngine.State.finished.
//
//  Transfer row is honest about transferUserInfo being queued and eventual,
//  not "sent to iPhone" the instant stop() returns.
//

import SwiftUI

struct SummaryView: View {
    var engine: SessionEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let summary = engine.lastSummary {
                    SummaryRow(label: "Duration", value: durationText(summary))
                    SummaryRow(label: "Windows classified", value: "\(summary.windowCount)")
                    SummaryRow(label: "Non-neutral", value: fractionText(summary))
                    SummaryRow(label: "Alerts", value: "\(summary.alertCount)")
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
