//
//  ExecutionGate.swift
//  RCProxy
//
//  Holds the requests made while RCProxy Desktop is expected, but not connected yet.
//

import Foundation
import RCProxyCore

/// Decides what happens to a request while no Mac performs the requests of the app.
///
/// RCProxy Desktop needs a moment to find the app and to connect to it. Without this, the requests made
/// in the meantime (the ones of the launch, typically) are performed by the app, and escape the mocks.
/// So when a Mac is expected, they wait for it, briefly.
///
/// A plain value: `DesktopStreamer` keeps it behind a lock, and does what it decides.
struct ExecutionGate: Sendable {

    typealias Completion = @Sendable (RemoteExecutionResult?) -> Void

    struct Pending: Sendable {
        let request: RemoteExecutionRequest
        let completion: Completion
    }

    /// A Mac performs the requests of the app.
    private(set) var hasExecutor = false
    /// A Mac is expected until then.
    private(set) var deadline: Date?
    /// The requests waiting for it, oldest first.
    private(set) var pending: [Pending] = []

    /// Keeps a request until a Mac performs it, or until nobody is expected anymore.
    /// `false`: there is nothing to wait for, the request goes its usual way.
    mutating func hold(_ request: RemoteExecutionRequest, completion: @escaping Completion, now: Date) -> Bool {
        guard !hasExecutor, let deadline, now < deadline else { return false }
        pending.append(Pending(request: request, completion: completion))
        return true
    }

    /// Expects a Mac until `date`. A wait under way is never shortened.
    mutating func expectExecutor(until date: Date) {
        guard !hasExecutor else { return }
        deadline = max(deadline ?? date, date)
    }

    /// A Mac performs the requests from now on. Returns the requests that were waiting for it.
    mutating func executorArrived() -> [Pending] {
        hasExecutor = true
        deadline = nil
        defer { pending = [] }
        return pending
    }

    /// No Mac performs the requests anymore.
    mutating func executorLeft() {
        hasExecutor = false
    }

    /// To call when a wait may be over. Returns the requests the app has to perform itself: nobody came.
    /// `nil` when nothing ended: no wait, a wait that was extended, or a Mac that arrived.
    mutating func expire(now: Date) -> [Pending]? {
        guard !hasExecutor, let deadline, now >= deadline else { return nil }
        self.deadline = nil
        defer { pending = [] }
        return pending
    }

    /// Stops waiting, whatever the reason. Returns the requests the app has to perform itself.
    mutating func giveUp() -> [Pending] {
        hasExecutor = false
        deadline = nil
        defer { pending = [] }
        return pending
    }

    /// Forgets a request that was cancelled while it waited. `false` when it was not waiting.
    mutating func cancel(id: String) -> Bool {
        guard let index = pending.firstIndex(where: { $0.request.id == id }) else { return false }
        pending.remove(at: index)
        return true
    }
}
