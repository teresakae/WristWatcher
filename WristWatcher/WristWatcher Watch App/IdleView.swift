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

                if let reason = engine.blockedReason {
                    Button("Start") {}
                        .buttonStyle(.borderedProminent)
                        .disabled(true)
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                Toggle("Non-neutral", isOn: Binding(
                    get: { engine.classifier.probability >= 0.5 },
                    set: { engine.classifier.probability = $0 ? 1.0 : 0.0 }
                ))
                .font(.caption2)
                #endif
            }
            .padding()
        }
    }
}

#Preview {
    IdleView(engine: SessionEngine())
}
