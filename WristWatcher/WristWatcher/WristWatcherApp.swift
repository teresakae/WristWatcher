//
//  WristWatcherApp.swift
//  WristWatcher
//
//  Created by Teresa Kae on 15/09/26.
//

import SwiftUI

@main
struct WristWatcherApp: App {
    @State private var receiver = Receiver()

    var body: some Scene {
        WindowGroup {
            ContentView(receiver: receiver)
        }
    }
}
