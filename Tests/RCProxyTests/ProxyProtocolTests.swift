import XCTest
import RCProxyCore
@testable import RCProxy

/// Plays the role of the server: answers the requests forwarded by `RCProxyProtocol`.
final class StubServerProtocol: URLProtocol, @unchecked Sendable {

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let url = request.url else { return }

        if url.path == "/fail" {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }

        let receivedBody = request.httpBody ?? request.bodyStream() ?? Data()
        let status = url.path == "/missing" ? 404 : 200
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json", "X-Received-Bytes": "\(receivedBody.count)"]
        )!
        let payload: [String: Any] = [
            "method": request.httpMethod ?? "",
            "echo": String(data: receivedBody, encoding: .utf8) ?? "",
            "header": request.value(forHTTPHeaderField: "X-Test") ?? ""
        ]
        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class ProxyProtocolTests: XCTestCase {

    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let serverConfiguration = URLSessionConfiguration.ephemeral
        serverConfiguration.protocolClasses = [StubServerProtocol.self]
        // Fresh storage for each test.
        RCProxy.start(with: URLSession(configuration: serverConfiguration), storageType: .session())
        session = URLSession(configuration: RCProxy.ephemeralConfiguration)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        super.tearDown()
    }

    /// Recording is asynchronous: waits until the request matching `predicate` shows up.
    private func recordedItem(
        timeout: TimeInterval = 5,
        where predicate: (RequestItem) -> Bool
    ) async -> RequestItem? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let item = await RCProxy.storage.fetch().first(where: predicate) {
                return item
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return nil
    }

    func testRecordsRequestAndResponse() async throws {
        var request = URLRequest(url: URL(string: "https://api.example.test/users/42?page=2&sort=name")!)
        request.httpMethod = "POST"
        request.setValue("yes", forHTTPHeaderField: "X-Test")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"name":"Leia"}"#.utf8)

        let (data, response) = try await session.data(for: request)

        // The app gets the real response…
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let echoed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(echoed["method"], "POST")
        XCTAssertEqual(echoed["echo"], #"{"name":"Leia"}"#, "The body must reach the server untouched")
        XCTAssertEqual(echoed["header"], "yes")

        // …and RCProxy recorded everything.
        let recorded = await recordedItem { $0.fullURL.contains("/users/42") && $0.isCompleted }
        let item = try XCTUnwrap(recorded)
        XCTAssertEqual(item.method, "POST")
        XCTAssertEqual(item.statusCode, 200)
        XCTAssertEqual(item.url, "https://api.example.test/users/42")
        XCTAssertEqual(item.queryParameters.map(\.name), ["page", "sort"])
        XCTAssertEqual(item.requestHeaders["X-Test"], "yes")
        XCTAssertEqual(item.requestBodyData, Data(#"{"name":"Leia"}"#.utf8))
        XCTAssertEqual(item.responseHeaders["Content-Type"], "application/json")
        XCTAssertEqual(item.responseBodyData, data)
        XCTAssertNotNil(item.duration)
        XCTAssertNil(item.errorDescription)
        XCTAssertTrue(item.cURL.hasPrefix("curl -X POST 'https://api.example.test/users/42?page=2&sort=name'"))
        XCTAssertTrue(item.cURL.contains(#"--data '{"name":"Leia"}'"#))
        XCTAssertTrue(item.cURL.contains("-H 'X-Test: yes'"))
    }

    func testRecordsHTTPErrors() async throws {
        let (_, response) = try await session.data(from: URL(string: "https://api.example.test/missing")!)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 404)

        let recorded = await recordedItem { $0.fullURL.hasSuffix("/missing") && $0.isCompleted }
        XCTAssertEqual(recorded?.statusCode, 404)
        XCTAssertEqual(recorded?.isError, true)
    }

    func testRecordsTransportErrors() async {
        do {
            _ = try await session.data(from: URL(string: "https://api.example.test/fail")!)
            XCTFail("The request should fail")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }

        let recorded = await recordedItem { $0.fullURL.hasSuffix("/fail") && $0.isCompleted }
        XCTAssertEqual(recorded?.statusCode, 0)
        XCTAssertNotNil(recorded?.errorDescription)
    }

    func testCancellingARequestIsHarmless() async {
        let task = session.dataTask(with: URL(string: "https://api.example.test/cancelled")!)
        task.resume()
        task.cancel()

        // The request was recorded when it started; nothing must blow up afterwards.
        let recorded = await recordedItem { $0.fullURL.hasSuffix("/cancelled") }
        XCTAssertNotNil(recorded)
    }

    func testManyConcurrentRequests() async throws {
        let session = try XCTUnwrap(self.session)
        try await withThrowingTaskGroup(of: Int.self) { group in
            for index in 0..<60 {
                group.addTask {
                    var request = URLRequest(url: URL(string: "https://api.example.test/burst/\(index)")!)
                    request.httpMethod = "PUT"
                    request.httpBody = Data("payload-\(index)".utf8)
                    let (data, _) = try await session.data(for: request)
                    return data.count
                }
            }
            for try await size in group {
                XCTAssertGreaterThan(size, 0)
            }
        }

        let deadline = Date().addingTimeInterval(5)
        var completed: [RequestItem] = []
        while Date() < deadline {
            completed = await RCProxy.storage.fetch().filter { $0.fullURL.contains("/burst/") && $0.isCompleted }
            if completed.count == 60 { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(completed.count, 60)
        XCTAssertTrue(completed.allSatisfy { $0.statusCode == 200 })
        for item in completed {
            let index = item.fullURL.components(separatedBy: "/").last ?? ""
            XCTAssertEqual(item.requestBodyData, Data("payload-\(index)".utf8))
        }
    }

    func testOnlyHTTPRequestsAreIntercepted() {
        XCTAssertTrue(RCProxyProtocol.canInit(with: URLRequest(url: URL(string: "https://example.com")!)))
        XCTAssertTrue(RCProxyProtocol.canInit(with: URLRequest(url: URL(string: "HTTP://example.com")!)))
        XCTAssertFalse(RCProxyProtocol.canInit(with: URLRequest(url: URL(string: "file:///tmp/a.json")!)))
        XCTAssertFalse(RCProxyProtocol.canInit(with: URLRequest(url: URL(string: "data:text/plain,hello")!)))
    }

    func testCurlEscapesSingleQuotes() {
        var request = URLRequest(url: URL(string: "https://example.com/search?q=it's")!)
        request.httpMethod = "POST"
        request.setValue("O'Brien", forHTTPHeaderField: "X-Name")

        let command = request.cURL(body: Data("it's a body".utf8))

        XCTAssertTrue(command.contains(#"'https://example.com/search?q=it'\''s'"#), command)
        XCTAssertTrue(command.contains(#"-H 'X-Name: O'\''Brien'"#), command)
        XCTAssertTrue(command.contains(#"--data 'it'\''s a body'"#), command)
    }
}
