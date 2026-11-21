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
//  No live label, no counts, no haptic, no chart, no progress ring: the
//  screen shows elapsed time and Stop only (measuring instrument, no live
//  feedback). The debug build also shows the raw sample count.
//

import SwiftUI

struct RunningView: View {
    var engine: SessionEngine
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ElapsedReadout(startedAt: engine.startedAt, isLuminanceReduced: isLuminanceReduced)
                #if DEBUG
                Text("\(engine.sampleCount) samples")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                #endif

                if !isLuminanceReduced {
                    Button("Stop") { engine.stop() }
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
            }
            .padding()
        }
    }
}

/// TimelineView-driven elapsed time, largest element on the screen. Schedule
/// and precision both follow \.isLuminanceReduced — see file header.
private struct ElapsedReadout: View {
    let startedAt: Date
    let isLuminanceReduced: Bool

    var body: some View {
        if isLuminanceReduced {
            TimelineView(.everyMinute) { context in
                text(for: context.date, secondsVisible: false)
            }
        } else {
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                text(for: context.date, secondsVisible: true)
            }
        }
    }

    @ViewBuilder
    private func text(for now: Date, secondsVisible: Bool) -> some View {
        let elapsed = max(0, Int(now.timeIntervalSince(startedAt)))
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
