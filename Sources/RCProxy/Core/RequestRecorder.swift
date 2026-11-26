//
//  RequestRecorder.swift
//  RCProxy
//
//  The single entry point of everything that gets recorded.
//

import Foundation
import RCProxyCore

/// Receives the requests from `RCProxyProtocol`, on whatever thread they happen, and processes them
/// one after the other: storage first, then RCProxy Desktop if it is connected.
///
/// Processing events sequentially guarantees that a request is always stored before its response,
/// and that viewers receive the states of a request in order.
final class RequestRecorder: Sendable {

    static let shared = RequestRecorder()

    private enum Event: Sendable {
        case started(RequestItem)
        case completed(id: String, completion: RequestCompletion)
        case viewerConnected(viewerID: String)
    }

    private let continuation: AsyncStream<Event>.Continuation

    private init() {
        let (stream, continuation) = AsyncStream<Event>.makeStream(bufferingPolicy: .unbounded)
        self.continuation = continuation

        // First request of this launch: if the switch was left on, RCProxy Desktop wants it too.
        DesktopStreamer.shared.resumeIfEnabled()

        Task.detached(priority: .utility) {
            // Requests that did not get their response yet. Storages may forget a request before
            // it completes (they are limited in size): viewers still deserve the full picture.
            var pending: [String: RequestItem] = [:]
            var pendingOrder: [String] = []
            let maxPending = 500

            for await event in stream {
                let storage = RCProxy.storage
                switch event {
                case .started(let item):
                    await storage.insert(item)
                    pending[item.id] = item
                    pendingOrder.append(item.id)
                    if pendingOrder.count > maxPending {
                        pending[pendingOrder.removeFirst()] = nil
                    }
                    DesktopStreamer.shared.broadcast(item)

                case .completed(let id, let completion):
                    let stored = await storage.complete(id: id, with: completion)
                    if var item = pending.removeValue(forKey: id) {
                        pendingOrder.removeAll { $0 == id }
                        completion.apply(to: &item)
                        DesktopStreamer.shared.broadcast(item)
                    } else if let stored {
                        DesktopStreamer.shared.broadcast(stored)
                    }

                case .viewerConnected(let viewerID):
                    // Oldest first, so that the viewer receives the requests in chronological order.
                    let items = await storage.fetch().reversed()
                    DesktopStreamer.shared.sendInitialState(Array(items), toViewer: viewerID)
                }
            }
        }
    }

    func requestStarted(_ item: RequestItem) {
        continuation.yield(.started(item))
    }

    func requestCompleted(id: String, completion: RequestCompletion) {
        continuation.yield(.completed(id: id, completion: completion))
    }

    /// A viewer just connected: it needs the requests recorded so far.
    func viewerConnected(viewerID: String) {
        continuation.yield(.viewerConnected(viewerID: viewerID))
    }
}
