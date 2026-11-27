//
//  RemoteLink.swift
//  RCProxyCore
//
//  Shared definitions of the link between an app embedding RCProxy and RCProxy Desktop.
//

import Foundation

/// Constants of the link between an app embedding RCProxy ("device") and a viewer such as RCProxy Desktop.
public enum RemoteLink {
    /// The MultipeerConnectivity service type.
    ///
    /// Apps embedding RCProxy must declare `_rcproxy._tcp` and `_rcproxy._udp`
    /// in the `NSBonjourServices` array of their Info.plist.
    public static let serviceType = "rcproxy"

    /// The Bonjour services to declare in `NSBonjourServices`.
    public static let bonjourServices = ["_rcproxy._tcp", "_rcproxy._udp"]

    /// Version of the wire protocol.
    public static let protocolVersion = 1

    enum DiscoveryKey {
        static let deviceID = "id"
        static let appName = "app"
        static let system = "os"
        static let model = "model"
        static let protocolVersion = "v"
    }
}

/// Describes an app embedding RCProxy, as seen by a viewer.
public struct RemoteDeviceInfo: Codable, Sendable, Hashable, Identifiable {
    /// A stable identifier of the app installation. It survives app relaunches.
    public var id: String
    /// The name of the device, e.g. "Living room".
    public var name: String
    /// The kind of device, e.g. "iPhone", "iPad" or "Apple TV".
    public var model: String
    /// "iOS", "tvOS"…
    public var systemName: String
    public var systemVersion: String
    public var appName: String
    public var appIdentifier: String
    public var appVersion: String
    /// The version of the RCProxy library embedded in the app.
    public var libraryVersion: String
    public var isSimulator: Bool

    public init(
        id: String,
        name: String,
        model: String,
        systemName: String,
        systemVersion: String,
        appName: String,
        appIdentifier: String,
        appVersion: String,
        libraryVersion: String,
        isSimulator: Bool
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.systemName = systemName
        self.systemVersion = systemVersion
        self.appName = appName
        self.appIdentifier = appIdentifier
        self.appVersion = appVersion
        self.libraryVersion = libraryVersion
        self.isSimulator = isSimulator
    }
}

/// Describes a viewer (RCProxy Desktop) asking to receive the requests of an app.
public struct RemoteViewerInfo: Codable, Sendable, Hashable, Identifiable {
    /// A stable identifier of the viewer installation.
    public var id: String
    /// The name of the computer, e.g. "Rémi's MacBook Pro".
    public var name: String
    /// A short code displayed on both sides so the user can check who is asking.
    public var pairingCode: String

    public init(id: String, name: String, pairingCode: String) {
        self.id = id
        self.name = name
        self.pairingCode = pairingCode
    }
}

/// Messages exchanged by a device and a viewer.
///
/// A peer that does not know a case (an older version) fails to decode the message and ignores it.
enum RemoteMessage: Codable, Sendable {
    // Device → viewer.

    /// First message of a connection: who is talking.
    case hello(RemoteDeviceInfo)
    /// A new request, or a new state of an already known request (matched by `id`).
    case upsert(RequestItem)
    /// Asks the viewer to perform a request and to answer with `.executionResult`.
    case execute(RemoteExecutionRequest)
    /// The app is not interested in the result of this request anymore.
    case cancelExecution(id: String)

    // Viewer → device.

    /// Tells whether the viewer wants to perform the requests of the app. Off until told otherwise.
    case delegation(Bool)
    case executionResult(RemoteExecutionResult)
}

extension String {
    /// Truncates the string so that its UTF-8 representation fits in `maxBytes`,
    /// without cutting a character in half.
    func truncated(toUTF8ByteCount maxBytes: Int) -> String {
        guard utf8.count > maxBytes else { return self }
        var result = ""
        var count = 0
        for character in self {
            let size = String(character).utf8.count
            if count + size > maxBytes { break }
            result.append(character)
            count += size
        }
        return result
    }
}
