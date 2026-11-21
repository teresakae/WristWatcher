//
//  WristWatcherApp.swift
//  WristWatcher
//
//  Created by Teresa Kae on 15/09/26.
//

import SwiftData
import SwiftUI

@main
struct WristWatcherApp: App {
    private let container: ModelContainer
    @State private var receiver: Receiver

    init() {
        // ponytail: a store that cannot open is unrecoverable for a read-only
        // history app; crash loudly rather than run with no storage.
        let container = try! ModelContainer(for: StoredSession.self)
        self.container = container
        _receiver = State(initialValue: Receiver(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(receiver: receiver)
        }
        .modelContainer(container)
    }
}
