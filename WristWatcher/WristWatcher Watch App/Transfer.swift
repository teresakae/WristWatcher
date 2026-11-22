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
//  Retry: the encoded summary is kept until delivery is confirmed, so a send
//  made before activation, or one that failed (e.g. session ended by the
//  system), can be resent via retry(). The iPhone dedups by sessionId.
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
    private(set) var lastError: String?
    private var pending: Data?

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
        lastError = nil
        guard let data = try? JSONEncoder().encode(summary) else {
            state = .failed
            lastError = "Couldn't encode"
            return
        }
        pending = data
        trySend()
    }

    func retry() {
        guard state == .failed else { return }
        trySend()
    }

    private func trySend() {
        guard let data = pending, WCSession.default.activationState == .activated else { return }
        state = .queued
        lastError = nil
        WCSession.default.transferUserInfo(["summary": data])
    }
}

extension Transfer: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { if self.state != .sent { self.trySend() } }
    }

    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        DispatchQueue.main.async {
            if let error {
                self.state = .failed
                self.lastError = error.localizedDescription
            } else {
                self.state = .sent
                self.pending = nil
            }
        }
    }
}
