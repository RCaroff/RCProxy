import XCTest
import os
@testable import RCProxyCore

/// Runs both ends of the link in the same process: a device (advertiser) and a viewer (browser),
/// talking over the real MultipeerConnectivity stack.
final class RemoteLinkLoopbackTests: XCTestCase {

    /// Collects what the viewer receives, so that the test can wait for specific events.
    private final class EventLog: Sendable {
        private let events = OSAllocatedUnfairLock<[RemoteBrowser.Event]>(initialState: [])

        func append(_ event: RemoteBrowser.Event) {
            events.withLock { $0.append(event) }
        }

        func first<T: Sendable>(_ transform: @Sendable (RemoteBrowser.Event) -> T?) -> T? {
            events.withLock { $0.lazy.compactMap(transform).first }
        }

        func count(where predicate: @Sendable (RemoteBrowser.Event) -> Bool) -> Int {
            events.withLock { $0.filter(predicate).count }
        }

        /// Polls until `transform` finds what it is looking for.
        func wait<T: Sendable>(timeout: TimeInterval, _ transform: @Sendable (RemoteBrowser.Event) -> T?) async -> T? {
            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if let value = first(transform) { return value }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            return first(transform)
        }
    }

    private func makeItem(_ id: String, bodySize: Int = 0, statusCode: Int = 200) -> RequestItem {
        var generator = SystemRandomNumberGenerator()
        return RequestItem(
            id: id,
            fullURL: "https://example.com/\(id)?token=abc",
            method: "GET",
            requestHeaders: ["Accept": "application/json"],
            responseBodyData: bodySize == 0 ? nil : Data((0..<bodySize).map { _ in UInt8.random(in: 0...255, using: &generator) }),
            statusCode: statusCode
        )
    }

    func testDeviceStreamsItsRequestsToAViewer() async throws {
        let device = RemoteDeviceInfo(
            id: "device-\(UUID().uuidString)", name: "Loopback Device", model: "iPhone", systemName: "iOS",
            systemVersion: "17.0", appName: "Loopback Tests", appIdentifier: "com.example.loopback",
            appVersion: "1.0 (1)", libraryVersion: "4.0.0", isSimulator: true
        )
        let viewerID = "viewer-\(UUID().uuidString)"

        let askedBy = OSAllocatedUnfairLock<RemoteViewerInfo?>(initialState: nil)
        let (connections, connectionsContinuation) = AsyncStream<String>.makeStream()
        let statuses = OSAllocatedUnfairLock<[RemoteAdvertiser.Status]>(initialState: [])

        let advertiser = RemoteAdvertiser(device: device, handlers: .init(
            shouldAccept: { viewer in
                askedBy.withLock { $0 = viewer }
                return true
            },
            viewerDidConnect: { connectionsContinuation.yield($0) },
            statusDidChange: { status in statuses.withLock { $0.append(status) } }
        ))
        let browser = RemoteBrowser(viewerID: viewerID, viewerName: "Loopback Viewer")
        let log = EventLog()
        let collector = Task {
            for await event in browser.events { log.append(event) }
        }
        defer {
            collector.cancel()
            browser.stop()
            advertiser.stop()
        }

        advertiser.start()
        browser.start()

        // 1. Discovery. It relies on Bonjour: environments without it cannot run this test.
        let found = await log.wait(timeout: 15) { event -> RemoteBrowser.Device? in
            if case .deviceFound(let found) = event, found.id == device.id { return found }
            return nil
        }
        guard let found else {
            throw XCTSkip("The device was not discovered: Bonjour seems unavailable in this environment.")
        }
        XCTAssertEqual(found.name, "Loopback Device")
        XCTAssertEqual(found.appName, "Loopback Tests")
        XCTAssertEqual(found.systemName, "iOS")
        XCTAssertEqual(found.model, "iPhone")

        // 2. Connection: the device is asked, with the pairing code.
        browser.connect(toDeviceWithID: device.id, pairingCode: "4821")
        let connectedViewer = await withTaskGroup(of: String?.self) { group -> String? in
            group.addTask {
                for await viewer in connections { return viewer }
                return nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        XCTAssertEqual(connectedViewer, viewerID, "The viewer should connect within 20 seconds")
        XCTAssertEqual(askedBy.withLock { $0 }, RemoteViewerInfo(id: viewerID, name: "Loopback Viewer", pairingCode: "4821"))
        let isConnected = await log.wait(timeout: 10) { event -> Bool? in
            if case .connected(let deviceID) = event, deviceID == device.id { return true }
            return nil
        }
        XCTAssertEqual(isConnected, true)

        // 3. Initial state: who the device is, then the history, including a body spanning many frames.
        let history = [makeItem("history-1"), makeItem("history-2", bodySize: 400_000)]
        advertiser.sendInitialState(history, toViewer: viewerID)

        let info = await log.wait(timeout: 10) { event -> RemoteDeviceInfo? in
            if case .deviceInfo(let info, _) = event { return info }
            return nil
        }
        XCTAssertEqual(info, device)

        let large = await log.wait(timeout: 20) { event -> RequestItem? in
            if case .request(let item, _) = event, item.id == "history-2" { return item }
            return nil
        }
        XCTAssertEqual(large?.responseBodyData, history[1].responseBodyData)
        let receivedFirst: Bool? = log.first { event -> Bool? in
            if case .request(let item, _) = event, item.id == "history-1" { return true }
            return nil
        }
        XCTAssertEqual(receivedFirst, true)

        // 4. Live requests: first pending, then completed. Order matters.
        advertiser.broadcast(makeItem("live", statusCode: 0))
        advertiser.broadcast(makeItem("live", statusCode: 201))

        let completed = await log.wait(timeout: 10) { event -> RequestItem? in
            if case .request(let item, _) = event, item.id == "live", item.statusCode == 201 { return item }
            return nil
        }
        XCTAssertEqual(completed?.fullURL, "https://example.com/live?token=abc")
        XCTAssertEqual(log.count { event in
            if case .request(let item, _) = event { return item.id == "live" }
            return false
        }, 2)

        // 5. Disconnection is noticed on both sides.
        browser.disconnect(fromDeviceWithID: device.id)
        let disconnected = await log.wait(timeout: 10) { event -> Bool? in
            if case .disconnected(let deviceID) = event, deviceID == device.id { return true }
            return nil
        }
        XCTAssertEqual(disconnected, true)

        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline, statuses.withLock({ $0.last }) != .advertising(viewers: []) {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(statuses.withLock { $0.last }, .advertising(viewers: []))
        XCTAssertTrue(statuses.withLock { $0.contains(.advertising(viewers: ["Loopback Viewer"])) })
    }

    func testDeclinedViewerDoesNotReceiveAnything() async throws {
        let device = RemoteDeviceInfo(
            id: "device-\(UUID().uuidString)", name: "Private Device", model: "Apple TV", systemName: "tvOS",
            systemVersion: "17.0", appName: "Loopback Tests", appIdentifier: "com.example.loopback",
            appVersion: "1.0 (1)", libraryVersion: "4.0.0", isSimulator: true
        )
        let advertiser = RemoteAdvertiser(device: device, handlers: .init(
            shouldAccept: { _ in false },
            viewerDidConnect: { _ in },
            statusDidChange: { _ in }
        ))
        let browser = RemoteBrowser(viewerID: "viewer-\(UUID().uuidString)", viewerName: "Unwanted Viewer")
        let log = EventLog()
        let collector = Task {
            for await event in browser.events { log.append(event) }
        }
        defer {
            collector.cancel()
            browser.stop()
            advertiser.stop()
        }

        advertiser.start()
        browser.start()

        let found = await log.wait(timeout: 15) { event -> Bool? in
            if case .deviceFound(let found) = event, found.id == device.id { return true }
            return nil
        }
        guard found == true else {
            throw XCTSkip("The device was not discovered: Bonjour seems unavailable in this environment.")
        }

        browser.connect(toDeviceWithID: device.id, pairingCode: "0000")
        let declined = await log.wait(timeout: 20) { event -> Bool? in
            if case .disconnected(let deviceID) = event, deviceID == device.id { return true }
            return nil
        }
        XCTAssertEqual(declined, true, "A declined invitation ends as a disconnection")

        advertiser.broadcast(makeItem("secret"))
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(log.count { event in
            if case .request = event { return true }
            if case .connected = event { return true }
            return false
        }, 0)
    }
}
