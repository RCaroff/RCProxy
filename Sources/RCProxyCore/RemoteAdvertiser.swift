//
//  RemoteAdvertiser.swift
//  RCProxyCore
//
//  Device side of the link: makes the app discoverable by RCProxy Desktop
//  and sends it the recorded requests.
//

import Foundation
@preconcurrency import MultipeerConnectivity

/// Advertises the app on the local network and streams requests to the viewers that connect.
///
/// Every viewer gets its own `MCSession`, so that viewers (and other devices) never see each other.
/// All the mutable state is confined to a private serial queue.
package final class RemoteAdvertiser: NSObject, @unchecked Sendable {

    package enum Status: Sendable, Equatable {
        case stopped
        /// Discoverable. `viewers` holds the names of the connected viewers, `executors` the names
        /// of those that perform the requests of the app.
        case advertising(viewers: [String], executors: [String] = [])
        case failed(String)
    }

    package struct Handlers: Sendable {
        /// Asks whether a viewer may receive the requests of this app.
        package var shouldAccept: @Sendable (RemoteViewerInfo) async -> Bool
        /// A viewer is connected and waits for `sendInitialState(_:toViewer:)`.
        package var viewerDidConnect: @Sendable (_ viewerID: String) -> Void
        package var statusDidChange: @Sendable (Status) -> Void

        package init(
            shouldAccept: @escaping @Sendable (RemoteViewerInfo) async -> Bool,
            viewerDidConnect: @escaping @Sendable (_ viewerID: String) -> Void,
            statusDidChange: @escaping @Sendable (Status) -> Void
        ) {
            self.shouldAccept = shouldAccept
            self.viewerDidConnect = viewerDidConnect
            self.statusDidChange = statusDidChange
        }
    }

    private final class Link {
        let session: MCSession
        let peer: MCPeerID
        let viewer: RemoteViewerInfo
        var isConnected = false
        var isReady = false
        /// The viewer asked to perform the requests of the app.
        var executes = false
        var assembler = RemoteFrameAssembler()

        init(session: MCSession, peer: MCPeerID, viewer: RemoteViewerInfo) {
            self.session = session
            self.peer = peer
            self.viewer = viewer
        }
    }

    private let device: RemoteDeviceInfo
    private let handlers: Handlers
    private let queue = DispatchQueue(label: "RCProxy.remote.advertiser", qos: .utility)
    private let peerID: MCPeerID

    // Confined to `queue`.
    private var advertiser: MCNearbyServiceAdvertiser?
    private var links: [ObjectIdentifier: Link] = [:]
    private var failure: String?
    private var executions: [String: Execution] = [:]

    /// A request handed over to a viewer, waiting for its result.
    private struct Execution {
        let link: ObjectIdentifier
        let completion: @Sendable (RemoteExecutionResult?) -> Void
    }

    package init(device: RemoteDeviceInfo, handlers: Handlers) {
        self.device = device
        self.handlers = handlers
        self.peerID = MCPeerID(displayName: RemoteLink.peerDisplayName(device.name))
        super.init()
    }

    // MARK: Lifecycle

    package func start() {
        queue.async { [self] in
            guard advertiser == nil else { return }
            failure = nil
            let advertiser = MCNearbyServiceAdvertiser(
                peer: peerID,
                discoveryInfo: discoveryInfo,
                serviceType: RemoteLink.serviceType
            )
            advertiser.delegate = self
            self.advertiser = advertiser
            DispatchQueue.main.async { advertiser.startAdvertisingPeer() }
            publishStatus()
        }
    }

    package func stop() {
        queue.async { [self] in
            guard let advertiser else { return }
            self.advertiser = nil
            advertiser.delegate = nil
            DispatchQueue.main.async { advertiser.stopAdvertisingPeer() }
            for link in links.values {
                link.session.delegate = nil
                link.session.disconnect()
            }
            links.removeAll()
            abandonExecutions { _ in true }
            failure = nil
            publishStatus()
        }
    }

    // MARK: Delegated requests

    /// Hands a request over to a viewer that asked to perform the requests of the app.
    ///
    /// `completion` is called exactly once, on a private queue: with the result, or with `nil` when no
    /// viewer performs the requests, when the viewer goes away, or when it does not answer in time.
    /// On `nil`, the app must perform the request itself.
    package func execute(_ request: RemoteExecutionRequest, completion: @escaping @Sendable (RemoteExecutionResult?) -> Void) {
        queue.async { [self] in
            guard let (key, link) = links.first(where: { $0.value.isConnected && $0.value.executes }),
                  let frames = try? RemoteFrameCodec.encode(.execute(request)) else {
                completion(nil)
                return
            }
            executions[request.id] = Execution(link: key, completion: completion)
            send(frames, over: link)

            // The viewer enforces the timeout of the request. This only covers a viewer that stopped answering.
            let id = request.id
            queue.asyncAfter(deadline: .now() + max(1, request.timeout) + Self.answerGracePeriod) { [self] in
                executions.removeValue(forKey: id)?.completion(nil)
            }
        }
    }

    /// Tells the viewer that the result of a request is not expected anymore. `completion` is not called.
    package func cancelExecution(id: String) {
        queue.async { [self] in
            guard let execution = executions.removeValue(forKey: id), let link = links[execution.link] else { return }
            send(.cancelExecution(id: id), over: link)
        }
    }

    /// Seconds granted to a viewer, on top of the timeout of a request, before the app takes the request back.
    private static let answerGracePeriod: TimeInterval = 10

    /// Gives the pending requests of some links back to the app.
    private func abandonExecutions(where predicate: (ObjectIdentifier) -> Bool) {
        for (id, execution) in executions where predicate(execution.link) {
            executions[id] = nil
            execution.completion(nil)
        }
    }

    // MARK: Sending

    /// Sends the description of the device and the already recorded requests (oldest first)
    /// to a viewer that just connected. Live requests are forwarded to it from then on.
    package func sendInitialState(_ items: [RequestItem], toViewer viewerID: String) {
        queue.async { [self] in
            guard let link = links.values.first(where: { $0.viewer.id == viewerID && $0.isConnected }) else { return }
            send(.hello(device), over: link)
            for item in items {
                send(.upsert(item), over: link)
            }
            link.isReady = true
        }
    }

    /// Sends a new request, or the new state of a request, to every connected viewer.
    package func broadcast(_ item: RequestItem) {
        queue.async { [self] in
            let ready = links.values.filter { $0.isReady }
            guard !ready.isEmpty, let frames = try? RemoteFrameCodec.encode(.upsert(item)) else { return }
            for link in ready {
                send(frames, over: link)
            }
        }
    }

    private func send(_ message: RemoteMessage, over link: Link) {
        guard let frames = try? RemoteFrameCodec.encode(message) else { return }
        send(frames, over: link)
    }

    private func send(_ frames: [Data], over link: Link) {
        for frame in frames {
            do {
                try link.session.send(frame, toPeers: [link.peer], with: .reliable)
            } catch {
                // The viewer went away: the session delegate will clean the link up.
                return
            }
        }
    }

    // MARK: Helpers

    private var discoveryInfo: [String: String] {
        [
            RemoteLink.DiscoveryKey.deviceID: device.id.truncated(toUTF8ByteCount: 64),
            RemoteLink.DiscoveryKey.appName: device.appName.truncated(toUTF8ByteCount: 64),
            RemoteLink.DiscoveryKey.system: device.systemName.truncated(toUTF8ByteCount: 16),
            RemoteLink.DiscoveryKey.model: device.model.truncated(toUTF8ByteCount: 32),
            RemoteLink.DiscoveryKey.protocolVersion: String(RemoteLink.protocolVersion)
        ]
    }

    private func publishStatus() {
        let status: Status
        if let failure {
            status = .failed(failure)
        } else if advertiser == nil {
            status = .stopped
        } else {
            let connected = links.values.filter { $0.isConnected }
            status = .advertising(
                viewers: connected.map { $0.viewer.name }.sorted(),
                executors: connected.filter { $0.executes }.map { $0.viewer.name }.sorted()
            )
        }
        handlers.statusDidChange(status)
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension RemoteAdvertiser: MCNearbyServiceAdvertiserDelegate {

    package func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer viewerPeer: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        guard let context, let viewer = try? JSONDecoder().decode(RemoteViewerInfo.self, from: context) else {
            invitationHandler(false, nil)
            return
        }
        let reply = UncheckedSendable(invitationHandler)
        Task { [self] in
            let accepted = await handlers.shouldAccept(viewer)
            queue.async { [self] in
                guard accepted, self.advertiser != nil else {
                    reply.value(false, nil)
                    return
                }
                // A viewer only ever has one live link.
                for (key, link) in links where link.viewer.id == viewer.id {
                    link.session.delegate = nil
                    link.session.disconnect()
                    links[key] = nil
                }
                let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
                session.delegate = self
                links[ObjectIdentifier(session)] = Link(session: session, peer: viewerPeer, viewer: viewer)
                reply.value(true, session)
            }
        }
    }

    package func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        let message = error.localizedDescription
        queue.async { [self] in
            failure = message
            publishStatus()
        }
    }
}

// MARK: - MCSessionDelegate

extension RemoteAdvertiser: MCSessionDelegate {

    package func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let key = ObjectIdentifier(session)
        queue.async { [self] in
            guard let link = links[key] else { return }
            switch state {
            case .connected:
                guard !link.isConnected else { return }
                link.isConnected = true
                publishStatus()
                handlers.viewerDidConnect(link.viewer.id)
            case .notConnected:
                link.session.delegate = nil
                links[key] = nil
                abandonExecutions { $0 == key }
                publishStatus()
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    package func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let key = ObjectIdentifier(session)
        queue.async { [self] in
            guard let link = links[key], let message = link.assembler.ingest(data) else { return }
            switch message {
            case .delegation(let enabled):
                guard link.executes != enabled else { return }
                link.executes = enabled
                if !enabled {
                    abandonExecutions { $0 == key }
                }
                publishStatus()
            case .executionResult(let result):
                guard let execution = executions[result.id], execution.link == key else { return }
                executions[result.id] = nil
                execution.completion(result)
            case .hello, .upsert, .execute, .cancelExecution:
                // Device → viewer messages: nothing to do with them here.
                break
            }
        }
    }

    package func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    package func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    package func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}

// MARK: - Shared helpers

/// Wraps a value that is only used in a way known to be safe across concurrency domains.
struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}

extension RemoteLink {
    /// `MCPeerID` raises an exception for empty names and for names longer than 63 UTF-8 bytes.
    static func peerDisplayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let truncated = (trimmed.isEmpty ? "RCProxy" : trimmed).truncated(toUTF8ByteCount: 63)
        return truncated.isEmpty ? "RCProxy" : truncated
    }
}
