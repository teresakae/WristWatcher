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
                ElapsedReadout(startedAt: engine.startedAt, isLuminanceReduced: isLuminanceReduced)
                AlertCountBadge(count: engine.alertCount)

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

/// Passive tally, not a live warning — deliberately not a bell. Nothing on
/// RunningView should read as an active "you're doing this wrong" cue; the
/// haptic carries that, the screen only logs a count (design §2.2).
private struct AlertCountBadge: View {
    let count: Int

    var body: some View {
        Label("\(count) posture alerts", systemImage: "exclamationmark.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
    }
}

#Preview {
    RunningView(engine: SessionEngine())
}
