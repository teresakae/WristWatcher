//
//  SessionDetailView.swift
//  WristWatcher
//
//  watcher-ui-design.md §3.2. Every row is LabeledContent — Dynamic Type
//  layout and a correct VoiceOver reading with no extra work. Diagnostics
//  section renders only when invalidationReason is non-nil; an empty
//  section is noise.
//

import Charts
import SwiftUI

struct SessionDetailView: View {
    let summary: SessionSummary

    var body: some View {
        List {
            Section("Session") {
                LabeledContent("Started", value: summary.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Ended", value: summary.endedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Duration", value: SessionSummary.format(seconds: summary.durationSeconds))
                if summary.endedBySystem {
                    LabeledContent("Ended by system", value: "Yes")
                }
            }
            Section("Activity") {
                ForEach(Activity.allCases, id: \.self) { activity in
                    LabeledContent(
                        activity.displayName,
                        value: "\(SessionSummary.format(seconds: summary.seconds(activity))) (\(summary.percent(activity))%)"
                    )
                }
            }
            if !summary.segments.isEmpty {
                Section("Timeline") {
                    SegmentTimeline(summary: summary)
                }
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
}

/// FR-9: one horizontal bar, one BarMark per segment, coloured by activity.
/// X is seconds from session start.
private struct SegmentTimeline: View {
    let summary: SessionSummary

    private static let colors: [Activity: Color] = [.typing: .blue, .mouse: .orange, .writing: .green, .rest: .gray]

    var body: some View {
        Chart(summary.segments, id: \.start) { segment in
            BarMark(
                xStart: .value("Start", segment.start),
                xEnd: .value("End", segment.end),
                y: .value("Session", "Activity")
            )
            .foregroundStyle(by: .value("Activity", segment.activity.displayName))
        }
        .chartForegroundStyleScale(
            domain: Activity.allCases.map(\.displayName),
            range: Activity.allCases.map { Self.colors[$0] ?? .gray }
        )
        .chartXScale(domain: 0...max(1, summary.durationSeconds))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let seconds = value.as(Int.self) { Text(SessionSummary.format(seconds: seconds)) }
                }
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 90)
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(summary: SessionSummary(
            sessionId: "preview",
            startedAt: Date(),
            endedAt: Date().addingTimeInterval(600),
            endedBySystem: false,
            secondsByActivity: ["typing": 300, "mouse": 200, "rest": 99],
            segments: [
                Segment(start: 1, end: 301, activity: .typing),
                Segment(start: 301, end: 501, activity: .mouse),
                Segment(start: 501, end: 600, activity: .rest),
            ],
            sampleRateHz: 99.7,
            modelIdentifier: "logreg",
            appVersion: "1.0",
            invalidationReason: nil
        ))
    }
}
