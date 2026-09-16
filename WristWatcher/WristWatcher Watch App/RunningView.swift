//
//  RunningView.swift
//  WristWatcher Watch App
//
//  watcher-ui-design.md §1.1, §2.2, §2.3 — the Always-On correction. The
//  watch stays frontmost, dimmed, for the whole session; this view drives
//  its elapsed readout off TimelineView instead of a hand-rolled Timer, and
//  switches schedule (and layout) on \.isLuminanceReduced so a dimmed
//  display that can't update more than once a minute never shows a stale
//  seconds field.
//
//  No live posture class, no chart, no progress ring — each already settled
//  in the design (§2.2) and not re-litigated here.
//

import SwiftUI

struct RunningView: View {
    var engine: SessionEngine
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isLuminanceReduced {
                    TimelineView(.everyMinute) { context in
                        elapsedText(context.date, secondsVisible: false)
                    }
                } else {
                    TimelineView(.periodic(from: engine.startedAt, by: 1)) { context in
                        elapsedText(context.date, secondsVisible: true)
                    }
                }

                Label("\(engine.alertCount) posture alerts", systemImage: "bell.badge")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)

                if !isLuminanceReduced {
                    Button("Stop") { engine.stop() }
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func elapsedText(_ now: Date, secondsVisible: Bool) -> some View {
        let elapsed = max(0, Int(now.timeIntervalSince(engine.startedAt)))
        let minutes = elapsed / 60
        let seconds = elapsed % 60

        if secondsVisible {
            Text(String(format: "%d:%02d", minutes, seconds))
                .font(.system(.largeTitle, design: .rounded))
                .monospacedDigit()
                .accessibilityLabel("\(minutes) minutes \(seconds) seconds")
        } else {
            Text("\(minutes) min")
                .font(.system(.largeTitle, design: .rounded))
                .monospacedDigit()
                .accessibilityLabel("\(minutes) minutes")
        }
    }
}

#Preview {
    RunningView(engine: SessionEngine())
}
