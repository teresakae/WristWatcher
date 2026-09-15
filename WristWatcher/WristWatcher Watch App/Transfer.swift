//
//  Transfer.swift
//  WristWatcher Watch App
//
//  D4: reduced from the collector's own Transfer.swift (WristWatch repo,
//  P2/P3, see docs/ARCHITECTURE.md §5 there). Most of that file does not
//  apply here — this app's own ARCHITECTURE.md §6 already calls for
//  `transferUserInfo`, not `transferFile`: the payload is a small dictionary,
//  not a file, so there's no queued-file state machine, no SHA/byte-count
//  metadata, no ACK, no custom retry. `transferUserInfo` queues and retries
//  on its own (WCSession persists undelivered items across launches).
//

import Foundation
import WatchConnectivity

final class Transfer: NSObject {
    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ summary: SessionSummary) {
        let session = WCSession.default
        guard session.activationState == .activated,
              let data = try? JSONEncoder().encode(summary) else { return }
        session.transferUserInfo(["summary": data])
    }
}

extension Transfer: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
