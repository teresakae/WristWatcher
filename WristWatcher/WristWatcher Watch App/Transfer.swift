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
//  UI pass: SummaryView's transfer row needs to know queued vs. sent vs.
//  failed rather than implying the record has already arrived.
//

import Foundation
import Observation
import WatchConnectivity

@Observable
final class Transfer: NSObject {
    enum TransferState: Equatable {
        case queued, sent, failed
    }

    private(set) var state: TransferState = .queued

    var isCompanionAvailable: Bool {
        WCSession.isSupported() && WCSession.default.isCompanionAppInstalled
    }

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ summary: SessionSummary) {
        state = .queued
        let session = WCSession.default
        guard session.activationState == .activated,
              let data = try? JSONEncoder().encode(summary) else {
            state = .failed
            return
        }
        session.transferUserInfo(["summary": data])
    }
}

extension Transfer: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        DispatchQueue.main.async { self.state = error == nil ? .sent : .failed }
    }
}
