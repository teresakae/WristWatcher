//
//  ContentView.swift
//  WristWatcher Watch App
//
//  UI pass: this is the RootView from watcher-ui-design.md §2 — it just
//  switches on SessionEngine.state. No NavigationStack, no TabView: three
//  states, nowhere to navigate to.
//

import SwiftUI

struct ContentView: View {
    @State private var engine = SessionEngine()

    var body: some View {
        switch engine.state {
        case .idle:
            IdleView(engine: engine)
        case .running:
            RunningView(engine: engine)
        case .finished:
            SummaryView(engine: engine)
        }
    }
}

#Preview {
    ContentView()
}
