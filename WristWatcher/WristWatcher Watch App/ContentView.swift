//
//  ContentView.swift
//  WristWatcher Watch App
//
//  Created by Teresa Kae on 15/09/26.
//

import SwiftUI

struct ContentView: View {
    @State private var engine = SessionEngine()

    var body: some View {
        VStack(spacing: 8) {
            Text(engine.isRunning ? "Running" : "Idle")
                .font(.headline)
            Text("\(String(format: "%.0f", engine.measuredHz)) Hz")
            Text("\(engine.windowedSampleCount) windows")
                .font(.caption)
            Button(engine.isRunning ? "Stop" : "Start") {
                engine.isRunning ? engine.stop() : engine.start()
            }
            // D3 gate control: scripts the stub classifier's output since
            // there is no real model until D5.
            Toggle("Non-neutral", isOn: Binding(
                get: { engine.classifier.probability >= 0.5 },
                set: { engine.classifier.probability = $0 ? 1.0 : 0.0 }
            ))
            .font(.caption)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
