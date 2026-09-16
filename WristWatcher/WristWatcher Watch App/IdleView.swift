//
//  IdleView.swift
//  WristWatcher Watch App
//
//  watcher-ui-design.md §2.1. Blocked state (motion unavailable, HealthKit
//  denied, no companion) replaces Start with a disabled control and one
//  sentence naming the cause — a greyed-out button with no explanation is
//  the failure mode this exists to prevent.
//
//  D5: the #if DEBUG "Non-neutral" toggle that used to live here is gone —
//  it scripted ScriptedClassifier's output "before D5 has a real model"
//  (its own former header comment). D5 landing retires it; Start now leads
//  to real enrollment (EnrollmentView), not a scripted probability.
//

import SwiftUI

struct IdleView: View {
    var engine: SessionEngine

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Ready")
                    .font(.title3)
                    .foregroundStyle(.primary)

                if let reason = engine.blockedReason {
                    BlockedNotice(reason: reason)
                } else {
                    Button("Start") { engine.start() }
                        .buttonStyle(.borderedProminent)
                        .handGestureShortcut(.primaryAction)

                    if let failure = engine.enrollmentFailure {
                        Text(failure)
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if let last = engine.lastSummary {
                        Text(last.startedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}

/// One sentence naming the cause, next to a disabled Start — the failure
/// mode this prevents is a greyed-out button with no explanation.
private struct BlockedNotice: View {
    let reason: String

    var body: some View {
        Button("Start") {}
            .buttonStyle(.borderedProminent)
            .disabled(true)
        Text(reason)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    IdleView(engine: SessionEngine())
}
