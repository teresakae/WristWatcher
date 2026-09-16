//
//  EnrollmentView.swift
//  WristWatcher Watch App
//
//  D5: docs/UI-SPEC.md has nothing on enrollment — it's a UI-SPEC gap, not a
//  design decision made and skipped. This is the smallest thing that fits
//  the existing screens' style: plain text cue, a countdown (same
//  TimelineView-driven pattern as RunningView's elapsed readout, not a
//  progress ring — UI-SPEC §5 excludes rings elsewhere in this app and
//  there's no reason to introduce one here), and a Cancel button.
//

import SwiftUI

struct EnrollmentView: View {
    var engine: SessionEngine

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Hold your wrist neutral")
                    .font(.title3)
                    .multilineTextAlignment(.center)

                TimelineView(.periodic(from: engine.startedAt, by: 1)) { context in
                    let remaining = max(0, 10 - Int(context.date.timeIntervalSince(engine.startedAt)))
                    Text("\(remaining)s")
                        .font(.system(.largeTitle, design: .rounded))
                        .monospacedDigit()
                        .accessibilityLabel("\(remaining) seconds remaining")
                }

                Button("Cancel") { engine.cancelEnrollment() }
                    .buttonStyle(.bordered)
                    .tint(.red)
            }
            .padding()
        }
    }
}

#Preview {
    EnrollmentView(engine: SessionEngine())
}
