//
//  RemoteBrowser.swift
//  RCProxyCore
//
//  Viewer side of the link: finds the apps embedding RCProxy on the local network
//  and receives their requests.
//

import Foundation
@preconcurrency import MultipeerConnectivity

/// Discovers the apps whose "RCProxy Desktop" switch is on, and receives their requests.
///
/// Consume `events` from a single task. All the mutable state is confined to a private serial queue,
/// and the events of a device are delivered in the order they were sent.
public final class RemoteBrowser: NSObject, @unchecked Sendable {

    /// An app visible on the local network.
    public struct Device: Sendable, Hashable, Identifiable {
        /// Stable identifier of the app installation.
        public let id: String
        /// The name of the device.
        public let name: String
        public let appName: String
        /// "iOS", "tvOS"…
        public let systemName: String
        /// "iPhone", "iPad", "Apple TV"…
        public let model: String

        public init(id: String, name: String, appName: String, systemName: String, model: String) {
            self.id = id
            self.name = name
            self.appName = appName
            self.systemName = systemName
            self.model = model
        }
    }

    public enum Event: Sendable {
        case deviceFound(Device)
        case deviceLost(deviceID: String)
        /// An invitation was sent; the device may be asking its user for confirmation.
        case connecting(deviceID: String)
        case connected(deviceID: String)
        /// The connection ended, or the invitation was declined or timed out.
        case disconnected(deviceID: String)
        /// Full description of a connected device.
        case deviceInfo(RemoteDeviceInfo, deviceID: String)
        /// A new request, or the new state of a known request (same `id`).
        case request(RequestItem, deviceID: String)
        case browsingFailed(String)
    }

    private final class Link {
        let session: MCSession
        let peer: MCPeerID
        let deviceID: String
        var assembler = RemoteFrameAssembler()

        init(session: MCSession, peer: MCPeerID, deviceID: String) {
            self.session = session
            self.peer = peer
            self.deviceID = deviceID
        }
    }

    /// The stream of everything happening on the link. Meant for a single consumer.
    public let events: AsyncStream<Event>

    private let continuation: AsyncStream<Event>.Continuation
    private let viewerID: String
    private let viewerName: String
    private let queue = DispatchQueue(label: "RCProxy.remote.browser", qos: .userInitiated)
    private let peerID: MCPeerID

    // Confined to `queue`.
    private var browser: MCNearbyServiceBrowser?
    private var peers: [String: MCPeerID] = [:]
    private var deviceIDs: [MCPeerID: String] = [:]
    private var links: [ObjectIdentifier: Link] = [:]

    /// - Parameters:
    ///   - viewerID: A stable identifier of this viewer. Devices use it to remember trusted viewers.
    ///   - viewerName: The name shown on the device when it asks for confirmation.
    public init(viewerID: String, viewerName: String) {
        self.viewerID = viewerID
        self.viewerName = viewerName
        self.peerID = MCPeerID(displayName: RemoteLink.peerDisplayName(viewerName))
        (events, continuation) = AsyncStream<Event>.makeStream(bufferingPolicy: .unbounded)
        super.init()
    }

    // MARK: Lifecycle

    public func start() {
        queue.async { [self] in
            guard browser == nil else { return }
            let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: RemoteLink.serviceType)
            browser.delegate = self
            self.browser = browser
            DispatchQueue.main.async { browser.startBrowsingForPeers() }
        }
    }

    public func stop() {
        queue.async { [self] in
            guard let browser else { return }
            self.browser = nil
            browser.delegate = nil
            DispatchQueue.main.async { browser.stopBrowsingForPeers() }
            for link in links.values {
                link.session.delegate = nil
                link.session.disconnect()
                continuation.yield(.disconnected(deviceID: link.deviceID))
            }
            links.removeAll()
            for deviceID in peers.keys {
                continuation.yield(.deviceLost(deviceID: deviceID))
            }
            peers.removeAll()
            deviceIDs.removeAll()
        }
    }

    // MARK: Connections

    /// Asks a device to send its requests. The device may ask its user for confirmation,
    /// showing `pairingCode` so that the user can check which computer is asking.
    public func connect(toDeviceWithID deviceID: String, pairingCode: String) {
        queue.async { [self] in
            guard let browser, let peer = peers[deviceID] else {
                continuation.yield(.disconnected(deviceID: deviceID))
                return
            }
            removeLinks(toDeviceWithID: deviceID)

            let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
            session.delegate = self
            links[ObjectIdentifier(session)] = Link(session: session, peer: peer, deviceID: deviceID)

            let viewer = RemoteViewerInfo(id: viewerID, name: viewerName, pairingCode: pairingCode)
            let context = try? JSONEncoder().encode(viewer)
            browser.invitePeer(peer, to: session, withContext: context, timeout: 60)
            continuation.yield(.connecting(deviceID: deviceID))
        }
    }

    public func disconnect(fromDeviceWithID deviceID: String) {
        queue.async { [self] in
            if removeLinks(toDeviceWithID: deviceID) {
                continuation.yield(.disconnected(deviceID: deviceID))
            }
        }
    }

    @discardableResult
    private func removeLinks(toDeviceWithID deviceID: String) -> Bool {
        var removed = false
        for (key, link) in links where link.deviceID == deviceID {
            link.session.delegate = nil
            link.session.disconnect()
            links[key] = nil
            removed = true
        }
        return removed
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension RemoteBrowser: MCNearbyServiceBrowserDelegate {

    public func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        queue.async { [self] in
            guard self.browser != nil else { return }
            let deviceID = info?[RemoteLink.DiscoveryKey.deviceID] ?? peerID.displayName
            // A peer can be reported several times (once per network interface): only the first one counts.
            // A different peer for the same device means that the app was relaunched.
            let isAlreadyKnown = peers[deviceID] == peerID
            peers[deviceID] = peerID
            deviceIDs[peerID] = deviceID
            guard !isAlreadyKnown else { return }
            continuation.yield(.deviceFound(Device(
                id: deviceID,
                name: peerID.displayName,
                appName: info?[RemoteLink.DiscoveryKey.appName] ?? "",
                systemName: info?[RemoteLink.DiscoveryKey.system] ?? "",
                model: info?[RemoteLink.DiscoveryKey.model] ?? ""
            )))
        }
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        queue.async { [self] in
            guard let deviceID = deviceIDs.removeValue(forKey: peerID) else { return }
            // The app may already be back under a new peer (relaunch): keep the newer one.
            guard peers[deviceID] == peerID else { return }
            peers[deviceID] = nil
            continuation.yield(.deviceLost(deviceID: deviceID))
        }
    }

    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        continuation.yield(.browsingFailed(error.localizedDescription))
    }
}

// MARK: - MCSessionDelegate

extension RemoteBrowser: MCSessionDelegate {

    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let key = ObjectIdentifier(session)
        queue.async { [self] in
            guard let link = links[key] else { return }
            switch state {
            case .connected:
                continuation.yield(.connected(deviceID: link.deviceID))
            case .notConnected:
                link.session.delegate = nil
                links[key] = nil
                continuation.yield(.disconnected(deviceID: link.deviceID))
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let key = ObjectIdentifier(session)
        queue.async { [self] in
            guard let link = links[key], let message = link.assembler.ingest(data) else { return }
            switch message {
            case .hello(let info):
                continuation.yield(.deviceInfo(info, deviceID: link.deviceID))
            case .upsert(let item):
                continuation.yield(.request(item, deviceID: link.deviceID))
            }
        }
    }

    public func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    public func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    public func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}
