//
//  IdleView.swift
//  WristWatcher Watch App
//
//  watcher-ui-design.md §2.1. Blocked state (motion unavailable, HealthKit
//  denied, no companion) replaces Start with a disabled control and one
//  sentence naming the cause — a greyed-out button with no explanation is
//  the failure mode this exists to prevent.
//
//  The D3/D5 gate driver (the "Non-neutral" toggle) lives here behind
//  #if DEBUG, de-emphasized below Start. It is scaffolding, not a settings
//  screen — §5 of the design excludes a settings screen explicitly.
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

                    if let last = engine.lastSummary {
                        Text(last.startedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                #if DEBUG
                DebugPostureToggle(classifier: engine.classifier)
                #endif
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

#if DEBUG
/// D3/D5 gate driver: scripts ScriptedClassifier's output. Scaffolding, not
/// a settings screen — see file header.
private struct DebugPostureToggle: View {
    let classifier: ScriptedClassifier

    var body: some View {
        Toggle("Non-neutral", isOn: Binding(
            get: { classifier.probability >= 0.5 },
            set: { classifier.probability = $0 ? 1.0 : 0.0 }
        ))
        .font(.caption2)
    }
}
#endif

#Preview {
    IdleView(engine: SessionEngine())
}
