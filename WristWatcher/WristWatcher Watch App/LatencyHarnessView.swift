//
//  LatencyHarnessView.swift
//  WristWatcher Watch App
//
//  D5 part 5. NOT wired into ContentView's RootView switch — this is a
//  one-time measurement tool, not a screen in the app's normal flow
//  (UI-SPEC.md's screen inventory doesn't include it and shouldn't).
//
//  To run it on the physical watch:
//
//    1. In WristWatcherApp.swift, temporarily replace `ContentView()` with
//       `LatencyHarnessView()` as the WindowGroup's root.
//    2. Build & run on a physical Apple Watch — not the Simulator
//       (HKWorkoutSession and real timing are both meaningless there).
//    3. Tap "Run benchmark", keep the wrist raised until it reports done.
//    4. Read the results off the screen, or from the Xcode console (each
//       row is also printed as a CSV line).
//    5. Revert WristWatcherApp.swift back to `ContentView()`.
//
//  Record the watch model and watchOS version by hand alongside the numbers
//  — PLATFORM-FACTS.md lists watchOS version as unknown; this run settles
//  it, but the settling happens in the thesis repo, not here (read-only).
//

import HealthKit
import SwiftUI

struct LatencyHarnessView: View {
    @State private var results: [LatencyResult] = []
    @State private var isRunning = false
    private let workout = WorkoutKeepAlive()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button(isRunning ? "Running…" : "Run benchmark") { run() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning)

                ForEach(results, id: \.modelName) { result in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.modelName).font(.caption).bold()
                        Text("mean \(fmt(result.meanMs)) sd \(fmt(result.sdMs))")
                            .font(.caption2)
                        Text("p50 \(fmt(result.p50Ms)) p95 \(fmt(result.p95Ms)) max \(fmt(result.maxMs))")
                            .font(.caption2)
                        Text("\(result.compiledSizeBytes / 1024) KB")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
    }

    private func fmt(_ ms: Double) -> String { String(format: "%.2f ms", ms) }

    private func run() {
        isRunning = true
        workout.start()
        Task.detached(priority: .userInitiated) {
            // Off the main actor — see file header.
            let measured = LatencyHarness.run()
            for r in measured {
                print("latency,\(r.modelName),\(r.compiledSizeBytes),\(r.meanMs),\(r.sdMs),\(r.p50Ms),\(r.p95Ms),\(r.maxMs)")
            }
            await MainActor.run {
                results = measured
                isRunning = false
                workout.stop()
            }
        }
    }
}

#Preview {
    LatencyHarnessView()
}
