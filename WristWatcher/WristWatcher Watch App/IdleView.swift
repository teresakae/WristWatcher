//
//  IdleView.swift
//  WristWatcher Watch App
//
//  watcher-ui-design.md §2.1. Blocked state (motion unavailable, HealthKit
//  denied, no companion) replaces Start with a disabled control and one
//  sentence naming the cause — a greyed-out button with no explanation is
//  the failure mode this exists to prevent.
//
//  Start goes straight to running: no enrollment step.
//

import SwiftUI

struct IdleView: View {
    var engine: SessionEngine
    @AppStorage("testPreset") private var testPreset = "real"

    var body: some View {
        NavigationStack {
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

                    if let label = testLabel {
                        Text("Test: \(label)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if let last = engine.lastSummary {
                        Text(last.startedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink("Latency test") { LatencyHarnessView() }
                    .font(.caption)
                NavigationLink("Test mode") { TestModeView() }
                    .font(.caption)
            }
            .padding()
        }
        }
    }

    /// Orange line under Start while a replay is active (launch arg or preset).
    private var testLabel: String? {
        if UserDefaults.standard.string(forKey: "replayScript") != nil { return "launch script" }
        return testPreset == "real" ? nil : TestPreset.named(testPreset).name
    }
}

/// Test-only setting for the black-box cases; persists until set back.
private struct TestModeView: View {
    @AppStorage("testPreset") private var testPreset = "real"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(TestPreset.all) { preset in
            Button {
                testPreset = preset.id
                dismiss()
            } label: {
                HStack {
                    Text(preset.name)
                    Spacer()
                    if preset.id == testPreset { Image(systemName: "checkmark") }
                }
            }
        }
        .navigationTitle("Test mode")
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
