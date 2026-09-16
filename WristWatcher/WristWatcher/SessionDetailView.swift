//
//  SessionDetailView.swift
//  WristWatcher
//
//  watcher-ui-design.md §3.2. Every row is LabeledContent — Dynamic Type
//  layout and a correct VoiceOver reading with no extra work. Diagnostics
//  section renders only when invalidationReason is non-nil; an empty
//  section is noise.
//

import SwiftUI

struct SessionDetailView: View {
    let summary: SessionSummary

    var body: some View {
        List {
            Section("Session") {
                LabeledContent("Started", value: summary.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Ended", value: summary.endedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Duration", value: durationText)
            }
            Section("Posture") {
                LabeledContent("Windows classified", value: "\(summary.windowCount)")
                LabeledContent("Non-neutral", value: "\(summary.nonNeutralWindowCount) (\(fractionText))")
                LabeledContent("Alerts fired", value: "\(summary.alertCount)")
                LabeledContent("Windows refused", value: "\(summary.windowsRefused)")
            }
            Section("Recording") {
                LabeledContent("Measured sample rate", value: "\(String(format: "%.0f", summary.sampleRateHz)) Hz")
                LabeledContent("Model", value: summary.modelIdentifier)
                LabeledContent("App version", value: summary.appVersion)
            }
            if let reason = summary.invalidationReason {
                Section("Diagnostics") {
                    LabeledContent("Invalidation reason", value: reason)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(summary.startedAt.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    NavigationStack {
        SessionDetailView(summary: SessionSummary(
            sessionId: "preview",
            startedAt: Date(),
            endedAt: Date().addingTimeInterval(600),
            sampleRateHz: 99.7,
            windowCount: 300,
            windowsRefused: 2,
            nonNeutralWindowCount: 45,
            alertCount: 3,
            modelIdentifier: "scripted-v0",
            appVersion: "1.0",
            invalidationReason: nil
        ))
    }
}
